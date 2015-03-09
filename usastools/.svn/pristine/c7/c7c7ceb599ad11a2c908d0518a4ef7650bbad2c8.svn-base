


module USASTools::SemTag


  # Represents a single semantic tag.
  class SemTag
    attr_reader :stack, :affinity, :modifiers, :name, :desc

    # Create a new (immutable) tag
    #
    # stack:      A list of categories in 'descending the tree' order: ['A', 1, 1, 1]
    # modifiers:  A set of modifier labels, not including +/- lowercase: ['m', 'f']
    # affinity:   The sum affinity modifiers for the tag
    # multi_word: Is this a multi-word-unit?
    # opts: (optional)  string:  The original string
    #                   name:    The name of the category from a taxonomy
    #                   desc:    The description of the category from a taxonomy
    #
    def initialize(stack, modifiers = [], affinity = 0, multi_word = false, opts = {})
      # Store data.
      @stack      = stack
      @modifiers  = modifiers.map{ |m| m.to_s.downcase }
      @affinity   = affinity.to_i
      @multi_word = multi_word

      # Optional
      @string = opts[:string]
      @name   = opts[:name]
      @desc   = opts[:desc]
    end

    def multi_word?
      !!@multi_word
    end

    def male?
      @modifiers.include?('m')
    end

    def female?
      @modifiers.include?('f')
    end

    def conceptual_anaphor?
      @modifiers.include?('c')
    end

    def neuter?
      @modifiers.include?('n')
    end

    def idiom?
      @modifiers.include?('i')
    end

    def rarity_one?
      @modifiers.include?('%')
    end

    def rarity_two?
      @modifiers.include?('@')
    end

    def affinity_string
      ((@affinity >= 0) ? '+' : '-') * @affinity.abs
    end

    # Test if this tag equals another.
    #
    # Does not compare name/description, which are optional
    def ==(other)
      other.is_a?(SemTag)         &&
      !other.is_a?(DefaultSemTag) &&
      other.affinity            == self.affinity &&
      other.multi_word?         == self.multi_word? &&
      other.stack               == self.stack &&
      other.male?               == self.male? &&
      other.female?             == self.female? &&
      other.conceptual_anaphor? == self.conceptual_anaphor? &&
      other.neuter?             == self.neuter? &&
      other.idiom?              == self.idiom? &&
      other.rarity_one?         == self.rarity_one? &&
      other.rarity_two?         == self.rarity_two?
    end

    # Serialise to a string.  Outputs a USAS-compatible
    # tag string (except that it outputs as UTF-8)
    def to_s
      # We have the original, so return it
      # return @string if(@string)

      # Add the letter-number part
      str = @stack[0..1]

      # Add dot-separated numbers
      i = 2
      while(@stack[i].is_a?(Numeric))
        str << ".#{@stack[i]}"
        i += 1
      end

      # Add affinity
      str << affinity_string

      # Add modifiers
      str += @modifiers

      # Append multi-word deely
      str << '[i' if multi_word?

      # Name/description
      # str << "|#{@name}" unless @name.nil?
      # str << "|#{@desc}" unless @desc.nil?

      return str.join
    end

    # Return a hash for insertion into Hash objects
    def hash
      to_s.hash
    end

  end

 
  # This class represents the 'Df' special tag.
  #
  # It exists to represent the Df entries in a lexicon,
  # and represents whatever match is least specific out of
  # a multi-word lexicon file
  class DefaultSemTag < SemTag
    attr_reader :stack, :affinity, :modifiers, :name, :desc

    # Create a new DefaultSemTag,
    # a tag that is unpopulated and acts as a placeholder to
    # spur lookup during analysis.
    #
    def initialize(str = nil)
      # Optional
      @string = str
    end

    def multi_word?
      false
    end

    def male?
    end

    def female?
    end

    def conceptual_anaphor?
    end

    def neuter?
    end

    def idiom?
    end

    def rarity_one?
    end

    def rarity_two?
    end

    def affinity_string
    end

    # Test if this tag equals another.
    #
    # Does not compare name/description, which are optional
    def ==(other)
      other.is_a?(DefaultSemTag)
    end

    # Serialise to a string.  Outputs a USAS-compatible
    # tag string (except that it outputs as UTF-8)
    def to_s
      return @string if @string
      return 'Df'
    end
  end


  # Represents compound semtags, separated by slashes in the official spec.
  #
  # Holds a list of SemTag objects, and provides a number of comparison
  # and aggregation metrics.  Overrides all comparison calls from tag
  class CompoundSemTag < SemTag

    attr_reader :tags

    def initialize(tags)
      @tags = tags
    end

    def stack
      @tags.map{|t| t.stack}
    end

    def affinity
      @tags.map{|t| t.affinity}
    end

    def modifiers
      @tags.map{|t| t.modifiers}
    end

    # Are all of the tags multi-word units?
    def multi_word?
      @tags.map{ |x| x.multi_word? }.inject{ |a, b| a && b }
    end

    def male?
      @tags.map{ |x| x.male? }.inject{ |a, b| a || b }
    end

    def female?
      @tags.map{ |x| x.female? }.inject{ |a, b| a || b }
    end

    def conceptual_anaphor?
      @tags.map{ |x| x.conceptual_anaphor? }.inject{ |a, b| a || b }
    end

    def neuter?
      @tags.map{ |x| x.neuter? }.inject{ |a, b| a || b }
    end

    def idiom?
      @tags.map{ |x| x.idiom? }.inject{ |a, b| a || b }
    end

    def rarity_one?
      @tags.map{ |x| x.rarity_one? }.inject{ |a, b| a || b }
    end

    def rarity_two?
      @tags.map{ |x| x.rarity_two? }.inject{ |a, b| a || b }
    end

    def affinity_string
      @tags.map{|t| t.affinity_string }
    end

    def name
      @tags.map{|t| t.name}.join('/')
    end

    def desc
      @tags.map{|t| t.desc}.join('/')
    end

    # Requires perfect set equality
    def ==(other)
      return false unless other.is_a?(CompoundSemTag)
      @tags.map{ |t| other.tags.include?(t) }.inject{ |a, b| a && b } && 
      other.tags.map{ |t| @tags.include?(t) }.inject{ |a, b| a && b }
    end

    def to_s
      # Don't display the multi-word item in *every* subtag
      @tags.map do |t| 
        str = t.to_s
        str = str[0..-3] if t.multi_word?
        str
      end.join('/') + ((multi_word?) ? '[i' : '')
    end
  end

end
