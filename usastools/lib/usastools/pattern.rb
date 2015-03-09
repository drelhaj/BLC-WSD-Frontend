

module USASTools::Pattern



  class Pattern

    attr_accessor :terms

    # Terms should be an array of PatternTerm objects.
    def initialize(terms)
      @terms = terms

      @terms.each{|t|
        raise "each term in a pattern should be a descendent of PatternTerm" unless t.is_a?(PatternTerm)
      }
    end

    # Does the word or array provided match this pattern?
    #
    def match?(words)
      # Load into an array if just one item
      words = words.split if words.is_a?(String)

      # Parse word_POS strings if an array is provided
      words_list = []
      # Iterate over the array and split the words from
      # their POS tags
      words.each do |w|
        if w.is_a?(String)
        w.strip!
        if m = w.match(/^(?<word>[^_]+)_(?<pos>[^\s]+)$/)
          words_list << {word: m[:word], pos: m[:pos]}
        else
          raise "invalid word format; use `word_POS'"
        end
        elsif w.is_a?(Hash) && w.has_key?(:word) && w.has_key?(:pos)
          words_list << w
        else
          raise "invalid word format; expected String or Hash but got #{w.class}"
        end
      end

      # Now words_list is an ordered list of word-pos pairs.
      return false if @terms.length > words_list.length
      words_list.each_index do |i|
        return false unless t = @terms[i]
        return false unless t.match?(words_list[i][:word].to_s, words_list[i][:pos].to_s)
      end
      return true
    end

    def ==(other)
      return false unless other.terms.length == self.terms.length
      terms.each_index do |i|
        return false if terms[i] != other.terms[i]
      end
      return true
    end

    def eql?(other)
      self == other
    end

    def length
      @terms.length
    end

    def to_s
      @terms.map{ |t| t.to_s}.join(" ")
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def hash
      to_s.hash
    end

  end



  # A single item from a multi-word USAS pattern.
  #
  # This is a superclass to two actual useful classes,
  # but does not represent much on its own
  class PatternTerm

    # Build a regexp pattern from a given USAS pattern string.
    def self.build_rx(string)
      # Match any Kleene stars but escape everything else
      string = Regexp.escape(string)
      string.gsub!('\*', '.*')
      return string
    end

    # Sorting.  
    # Uses orthographic alphabetical sort
    def <=>(other)
      to_s <=> other.to_s
    end

    def ==(other)
      return other.to_s == to_s
    end

    def hash
      to_s.hash
    end

    def eql?(other)
      self == other
    end
  end


  # A single word pattern, consisting of a word
  # and a POS tag.
  class WordPatternTerm < PatternTerm

    attr_reader :word, :pos

    def initialize(word, pos)
      @word = word
      @pos  = pos

      @pattern = /^#{PatternTerm.build_rx(word)}_#{PatternTerm.build_rx(pos)}$/
    end

    def match?(word, pos = nil)
      word = "#{word}_#{pos}" if pos
      !!(@pattern =~ word)
    end

    def =~(word)
      !!(@pattern =~ word)
    end

    def to_s
      "#{word}_#{pos}"
    end
  end

  # Represents a POS pattern term,
  #
  # {POS/POS/POS}
  #
  class POSPatternTerm < PatternTerm
    
    attr_reader :poses

    def initialize(poses)
      @poses = poses

      @patterns = []
      @poses.each do |pos|
        @patterns << /^#{PatternTerm.build_rx(pos)}$/
      end
    end

    def match?(pos)
      @patterns.each do |rx|
        return true if pos =~ rx
      end
      return false
    end

    alias :"==~" :match?

    def to_s
      "{#{poses.join('/')}}"
    end

  end






end



