

# FIXME: this defeats the purpose of partial includes,
# but saves duplicating the resource location code.
require 'usastools' 

require 'usastools/pattern'

require 'usastools/rx_parser'

module USASTools::Pattern

  class Parser

    # Create a parser for USAS tag lookup patterns
    def initialize(parse_cb = nil, sem_cb = nil)
      @parse_cb = parse_cb
      @sem_cb   = sem_cb
    end

    # Parse a string with whitespace-separated pattern terms
    def parse_multiword_pattern(str)
      # Parse the string
      @p = USASTools::RegexParser.new(str, @parse_cb)
      p_pattern
      p_eos

      # Comprehend the tokens
      @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
      pattern = s_shift_pattern
      s_shift_eos

      # Clean up
      @p, @l = nil, nil

      return pattern
    end

    # Parse a single term from a multiword pattern.
    def parse_pattern_term(str)
      # Parse the string
      @p = USASTools::RegexParser.new(str, @parse_cb)
      p_pattern_term
      p_eos

      # Comprehend the tokens
      @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
      term = s_shift_pattern_term
      s_shift_eos

      # Clean up
      @p, @l = nil, nil

      return term
    end

    # # Parse a string with a single-word pattern pair in it
    # def parse_singleword_pattern(str)
    #   # Parse the string
    #   @p = USASTools::RegexParser.new(str, @parse_cb)
    #   p_eos

    #   # Comprehend the tokens
    #   @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
    #   s_shift_eos

    #   # Clean up
    #   @p, @l = nil, nil

    #   return compound_tag
    # end

    private


    ## =======================================================
    # Semantic analysis below.

    # Construct a whole pattern and return it
    def s_shift_pattern
      terms = []

      all_terms_are_pos_patterns = true
      while term = s_shift_pattern_term
        terms << term
        all_terms_are_pos_patterns = false if term.is_a?(USASTools::Pattern::WordPatternTerm)
      end

      # All terms cannot be POS patterns
      raise USASTools::ParseError, "pattern does not contain any word terms" if all_terms_are_pos_patterns

      return USASTools::Pattern::Pattern.new(terms)
    end

    # Construct a single pattern term
    # and return it
    def s_shift_pattern_term
      return s_shift_pos_pattern_term if @l.peek(:pospattern)
      return s_shift_word_pattern_term if @l.peek(:word)
      # nothing!
    end

    # Construct a single POS pattern and return it
    # Requires at least one pos on the stack
    def s_shift_pos_pattern_term
      @l.shift(:pospattern) # Pattern header

      poses = [@l.shift(:pos)]
      poses << @l.shift(:pos) while @l.peek(:pos)

      return USASTools::Pattern::POSPatternTerm.new(poses)
    end

    # Construct a single word pattern and return it
    def s_shift_word_pattern_term
      word  = @l.shift(:word)
      pos   = @l.shift(:pos)

      return USASTools::Pattern::WordPatternTerm.new(word, pos)
    end

    # Shift the end of string char.
    def s_shift_eos
      @l.shift(:eos)
    end


    ## =======================================================
    # RD parser below.
    # This parser tokenises on-the-fly using regexp.

    # A pattern is a full string of pattern terms
    # separated by whitespace
    #
    # pattern = pattern-term, [ ' '*, pattern-term];
    def p_pattern
      p_pattern_term
      while @p.peek(/^\s+/)
        @p.consume(/^\s+/, nil, 'pattern term')
        p_pattern_term
      end
    end


    # A pattern-term is either a word pattern or a POS pattern
    #
    # 
    def p_pattern_term
      if @p.peek(/^{/)
        # POS pattern
        p_pos_pattern
      else
        # word pattern
        p_word_pattern
      end
    end

    # A pos pattern is a slash-separated list of POSs in braces
    def p_pos_pattern
      @p.consume(/^{/, :pospattern, 'opening brace')
      
      p_pos
      while @p.peek(/^\//)
        @p.consume(/^\//, nil, 'slash')
        p_pos
      end

      @p.consume(/^}/, nil, 'closing brace')
    end

    # A pos is any sequence of chars that isn't an end brace,
    # an underscore, or whitespace
    def p_pos
      @p.consume(/^[^}^\/^_^\s]+/, :pos, 'part of speech')
    end

    # A word pattern is a word, an underscore, then a pos
    def p_word_pattern
      p_word
      @p.consume(/^_/, nil, 'underscore')
      p_pos
    end

    # A word is any character that isn't whitespace
    # or an underscore
    def p_word
      @p.consume(/^[^_^\s]+/, :word, 'word')
    end


    # End of string is
    # ^$
    def p_eos
      @p.consume(/^$/, :eos, 'end of string')
    end

  end

end


