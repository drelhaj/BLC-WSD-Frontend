
require 'usastools/lexicon'

module USASTools::Lexicon

  class MultiWordLexicon < Lexicon

    attr_reader :store

    def initialize(version = USASTools::Lexicon::VERSIONS[-1])
      super(:multi, version)
      @store = {}
    end

    def get(pattern)
      @store[pattern]
    end

    def get_patterns
      @store.keys
    end

    def add(pattern, tags)
      @store[pattern] = tags
    end

    def delete(pattern)
      @store.delete(pattern)
    end

    def merge_entry(pattern, tags)
      if @store[pattern]
        tags.each{ |t| @store[pattern] << tags unless @store[pattern].include?(t) }
      else
        add(pattern, tags)
      end
    end

    def pattern_count
      @store.size
    end

    def size
      pattern_count
    end

    def first_match(words)
      each_match do |pattern, tags|
        return tags
      end
      return nil
    end

    def last_match(words)
      ret_tags = nil
      each_match do |pattern, tags|
        ret_tags = tags
      end
      return ret_tags
    end

    def each_match(words, &blk)
      @store.each do |pattern, tags|
        yield(pattern, tags) if pattern.match?(words)
      end
    end

    def matches(words)
      result = []
      each_match(words) do |pattern, tags|
        result << {pattern: pattern, tags: tags}
      end
      return result
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
      raise ArgumentError, "cannot merge lexicons of differing type (#{type} vs #{other.type})" unless type == other.type

      # Get sorted key lists
      keys   = ((get_patterns || []) + (other.get_patterns || [])).uniq

      # puts "Merging self (items)"
      keys.each do |pattern|


        # Read POSes for each
        self_tags  = get(pattern)
        other_tags = other.get(pattern)

        # 'quick merge' if either is nil
        if self_tags == nil && other_tags && policy[:in_other] == :other
          # 0|1
          # puts "ins [bulk]"
          add(pattern, other.get(pattern))
        elsif self_tags && other_tags == nil && policy[:in_self] == :other
          # 1|0
          # puts "del [bulk]"
          @store.delete(pattern)
        elsif self_tags && other_tags
          # 1|1
          case policy[:in_both]
            when :other
              # puts "add"
              add(pattern, other.get(pattern))
            when :merge
              # puts "merge"
              merge_entry(pattern, other.get(pattern))
            when :drop
              # puts "drop"
              delete(pattern)
          end

        # else # 0|0 should be impossible...
        end

      end
    end


    # Write the lexicon to a filename or IO object
    def write(io_or_filename, pretty = false)
      # Open a handle in the right encoding if not passed an io
      fout = io_or_filename.is_a?(IO) ? io_or_filename : File.open(io_or_filename.to_s, mode: 'w',
                encoding: USASTools::Lexicon::get_feature_by_version(version, :encoding))
  
      # Write header
      fout.write("#{HEADER_MAGIC_NUMBER}_#{version}_mw\n")

      # Establish min pattern width for columnular output
      if pretty
        min_col_width = [store.keys.map{ |p| p.to_s.length }.max, 150].min
      end

      # Write items in-order
      store.keys.sort.each do |pattern|
        # Get data and convert to string
        tags          = @store[pattern]
        pattern_str   = pattern.to_s
        tags_str      = tags.join(' ')

        # Compose output in normal or pretty (padded) format
        if pretty
          pattern_str += ' '*(min_col_width - pattern_str.length)
        end

        fout.write("#{pattern_str} \t #{tags_str}\n")
      end

    ensure
      fout.close if fout && !io_or_filename.is_a?(IO)
    end

  end


end

