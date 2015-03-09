

require 'usastools/lexicon'

module USASTools::Lexicon

  # Represents a lexicon, which is a large table of
  #
  #  * words (or multi-word-units), each of which may have many:
  #  * Senses (parts of speech), each of which may have many:
  #  * Tags
  class SingleWordLexicon < Lexicon

   
    # Create an empty lexicon
    def initialize(version = USASTools::Lexicon::VERSIONS[-1])
      super(:single, version)
      @store = {}
    end


    # Retrieve all the semtags of a word from the lexicon
    def get(word, sense = nil)
      return nil unless @store[word].is_a?(Hash)
      return @store[word] if sense == nil
      return @store[word][sense]
    end


    # Retrieve all the senses of the word from the lexicon
    def get_senses(word)
      return nil unless @store[word]
      return @store[word].keys
    end


    # Return a list of words in this lexicon
    def get_words
      return @store.keys
    end


    # Yield (word) for each word in the lexicon
    def each_word
      get_words.each do |w|
        yield(w)
      end
    end

    # Yield (word, sense, [tags]) for each sense, for each word in the lexicon
    def each_word_sense
      each_word do |w|
        get_senses(w).each do |s|
          yield(w, s, get(w, s))
        end
      end
    end

    def each_sense(word)
      get_senses(word).each do |s|
        yield(word, s, get(word, s))
      end
    end


    # Put a word and sense into the lexicon
    #
    # Will overwrite any entries.
    def add(word, sense, tags = [])
      @store[word] = {} unless @store[word]
      @store[word][sense] = tags
    end

    def delete(word, sense=nil)
      return nil unless @store[word]
      return @store.delete(word) if sense == nil
      return nil unless @store[word][sense]
      return @store[word].delete(sense)
    end


    # Add but don't overwrite the tag list
    def merge_entry(word, sense, tags)
      @store[word] = {} unless @store[word]
      @store[word][sense] = [] unless @store[word][sense]

      tags.each do |t|
        @store[word][sense] << t unless @store[word][sense].include?(t)
      end
    end


    # Count words
    def word_count
      @store.size
    end


    # Count senses
    def sense_count
      @store.values.map{|v| v.size}.inject(0, :+)
    end


    # Count tags
    def semtag_count
      @store.values.map{ |v| v.values.map{ |t| t.size }.inject(0, :+) }.inject(0, :+)
    end

    def size
      sense_count
    end


    # Merge another lexicon into this one.  Takes a policy description thus:
    #
    #  in self | in other
    #  ------------------
    #     0    |    0    no action
    #     0    |    1    in_other: can take value from :other or :self  (default is :other)
    #     1    |    0    in_self: can take value from :other or :self   (default is :self)
    #     1    |    1    in_both: can take value from :other, :self, :drop, or :merge the two (default is :other)
    #
    def merge_lexicon(other, policy = {in_other: :other, in_self: :self, in_both: :other})
      raise ArgumentError, "cannot merge lexicons of differing type (#{type} vs #{other.type}" unless type == other.type

      # Get sorted key lists
      keys   = ((get_words || []) + (other.get_words || [])).uniq{ |w| w.hash }

      # puts "Merging self (items)"
      keys.each do |word|

        # Read POSes for each
        self_poses  = get_senses(word)
        other_poses = other.get_senses(word)

        # 'quick merge' if either is nil
        if self_poses == nil && other_poses && policy[:in_other] == :other
          # 0|1
          # puts "ins [bulk]"
          @store[word] = other.get(word)
        elsif self_poses && other_poses == nil && policy[:in_self] == :other
          # 1|0
          # puts "del [bulk]"
          delete(word)
        elsif self_poses && other_poses
          # 1|1
          # Both match, so enforce policy on a per-pos basis
          poses = ((self_poses || []) + (other_poses || [])).uniq

          poses.each do |pos|
            if get(word, pos) == nil && other.get(word, pos) && policy[:in_other] == :other
              # 0|1
              # puts "ins"
              add(word, pos, other.get(word, pos))
            elsif self.get(word, pos) && other.get(word, pos) == nil && policy[:in_self] == :other
              # 1|0
              # puts "del"
              delete(word, pos)
            elsif self.get(word, pos) && other.get(word, pos)
              # 1|1
              case policy[:in_both]
                when :other
                  # puts "over"
                  add(word, pos, other.get(word, pos))
                when :merge
                  # puts "merge"
                  merge_entry(word, pos, other.get(word, pos))
                when :drop
                  delete(word, pos)
              end
            # else # 0|0 impossible again, in theory
            end
          end

        # else # 0|0 should be impossible...
        end

      end
    end

    
    # Release resources
    def close
    end


    # Write the lexicon to a filename or IO object
    def write(io_or_filename, pretty=false)
      # Open a handle in the right encoding if not passed an io
      fout = io_or_filename.is_a?(IO) ? io_or_filename : File.open(io_or_filename.to_s, mode: 'w',
                encoding: USASTools::Lexicon::get_feature_by_version(version, :encoding))
  
      # Write header
      fout.write("#{HEADER_MAGIC_NUMBER}_#{version}_sw\n")

      if pretty
        min_word_width = [@store.keys.map{ |w| w.to_s.length}.max, 50].min
        min_pos_width  = [@store.keys.map{ |w| @store[w].map{ |p, tags| p.to_s.length }.max }.max, 20].min
      end

      # Write items
      @store.keys.sort.each do |word|
        each_sense(word) do |word, pos, tags|
          word_str  = word.to_s
          pos_str   = pos.to_s
          tags_str  = tags.join(' ')
  
          if pretty
            word_str += ' '*(min_word_width - word_str.length)
            pos_str  += ' '*(min_pos_width - pos_str.length)
          end

          fout.write("#{word_str} \t #{pos_str} \t #{tags_str}\n")
        end
      end
    ensure
      fout.close if fout && !io_or_filename.is_a?(IO)
    end


  end

end
