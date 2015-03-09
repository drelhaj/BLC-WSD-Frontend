
# FIXME: this defeats the purpose of partial includes,
# but saves duplicating the resource location code.
require 'usastools' 

require 'usastools/semtag/formats'


require 'usastools/rx_parser'

module USASTools::SemTag

  class Parser

    # Create a new USASTagParser with description data from
    # the given YAML file
    #
    # If taxonomy is true, the default one is loaded from
    # USASTools::default_sem_taxonomy
    #
    # Set parse_cb to a callback that is called when an error occurs
    # in the parsing stage.  It must accept the arguments (line, position, string, expected_regex)
    #
    # Set sem_cb to a callback called when an error occurs in semantic analysis.
    # It must accept (token_num, string, type, expected_type)
    #
    # If the above two are set to nil, the parser will throw exceptions instead.
    def initialize(taxonomy = nil, parse_cb = nil, sem_cb = nil)
      if taxonomy == true
        @descriptions = USASTools::default_sem_taxonomy
      else
        @descriptions = taxonomy
      end

      @parse_cb = parse_cb
      @sem_cb   = sem_cb
    end

    # Will this parser also validate input against
    # a list?
    def validate?
      return !!@descriptions
    end

    # Validate a tag.
    #
    # If #self.validate?, then this will
    # check the taxonomy given, else it
    # will do very basic checks only.
    #
    # Returns false if invalid, true if valid
    def valid?(tag, test_name = false)
    
      # Process array if so
      return tag.map{ |t| self.valid?(t) }.inject{ |a, b| a && b } if tag.is_a?(Array)
     
      # Process compound tag if so
      return tag.tags.map{ |t| self.valid?(t)}.inject{ |a, b| a && b } if tag.is_a?(CompoundSemTag)

      # Check the stack is vaguely sensible
      valid   = true
      valid &&= (tag.stack[0].to_s =~ /[A-Z]/) != nil
      valid &&= tag.stack.length > 1
      valid &&= tag.affinity.abs <= 3
      valid &&= tag.affinity.to_i.to_s == tag.affinity.to_s
      valid &&= (tag.modifiers.join =~ /^[fmnci@%]*$/) != nil

      # If we have a taxonomy, use it
      return valid unless validate?

      # Check stack against taxonomy
      found, name, description = s_valid_tag?(tag.stack.dup) 
      valid &&= found
      if test_name
        valid &&= name        == tag.name if tag.name
        valid &&= description == tag.desc if tag.desc
      end

      return valid
    end

    # Augment a tag with name and description from the taxonomy.
    #
    # Returns a new tag object with the info added (since tags are immutable)
    # Raises an exception if validate? is not set
    def augment(tag)
      raise ParseError, "cannot augment tag information: no taxonomy set." unless validate?

      # Process array if so
      return tag.map{ |t| self.augment(t) } if tag.is_a?(Array)
     
      # Process compound tag if so
      return tag.dup.tags.map{ |t| self.augment(t) } if tag.is_a?(CompoundSemTag)

      # Look stuff up from the stack
      found, name, description = s_valid_tag?(tag.stack.dup)
      raise ParseError, "cannot augment tag information: tag not found: #{tag}" unless found

      # And then return a tag with the info added
      return SemTag.new(tag.stack, tag.modifiers, tag.affinity,
                               name: name,
                               desc: description,
                             string: tag.to_s
                       )
    end

    alias :lookup :augment

    # Parse a string containing many space-separated compound tags
    def parse_tags(str, df_valid = false)
      @df_valid = df_valid

      # Parse the string
      @p = USASTools::RegexParser.new(str, @parse_cb)
      p_tags
      p_eos

      # Comprehend the tokens
      @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
      tags = s_shift_tags
      s_shift_eos

      # Clean up
      @p, @l = nil, nil

      return tags
    end

    # Parse a single compound tag
    def parse_compound_tag(str, df_valid = false)
      @df_valid = df_valid

      # Parse the string
      @p = USASTools::RegexParser.new(str, @parse_cb)
      p_compound_tag
      p_eos

      # Comprehend the tokens
      @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
      compound_tag = s_shift_compound_tag
      s_shift_eos

      # Clean up
      @p, @l = nil, nil

      return compound_tag
    end

    # Parse a single tag.
    def parse_tag(str, df_valid = false)
      @df_valid = df_valid

      # Parse the string
      @p = USASTools::RegexParser.new(str, @parse_cb)
      p_tag
      p_multi_word_modifier if @p.peek(/^\[i/)
      p_eos

      # Comprehend the tokens
      @l = USASTools::RegexAnalyser.new(@p.stack, @sem_cb)
      tag = s_shift_tag
      s_shift_eos

      # Clean up
      @p, @l = nil, nil

      return tag
    end


    private


    ## =======================================================
    # Semantic analysis below.

    # Shift a list of tags from the parse stack,
    # returning a list of objects that are either Tags or
    # CompoundSemTags
    def s_shift_tags
      tags = [s_shift_compound_tag]

      while(@l.peek(:also))
        @l.shift(:also)
        tags << s_shift_compound_tag
      end

      return tags
    end

    # Parse a (possibly) compound tag from the parse stack
    # Returns either a SemTag, or a CompoundSemTag
    def s_shift_compound_tag
      tags = [s_shift_tag_data]

      while(@l.peek(:compound))
        @l.shift(:compound)
        tags << s_shift_tag_data
      end
    
      # Check for multiword unit status
      multi_word = false
      if @l.peek(:multi_word)
        @l.shift(:multi_word)
        multi_word = true
      end

      # If only one tag, create it and add multi_word status
      if tags.length == 1
        type, tag_cat, modifiers, affinity, str = tags[0]
        str += "[i" if multi_word
        return s_create_tag(tag_cat, modifiers, affinity, multi_word, str) if type == :tag
        return DefaultSemTag.new(str) if type == :default_tag
      end

      # else create all the tags
      tags.map! do |t|
        type, tag_cat, modifiers, affinity, str = t
        if type == :tag
          s_create_tag(tag_cat, modifiers, affinity, multi_word, str)
        elsif type == :default_tag
          DefaultSemTag.new(str)
        end
      end

      # and add them
      return CompoundSemTag.new(tags)
    end

    # Read tag data from the list
    # 
    # Does not build the tag, that is the job of shift_compound_tag
    # when it knows about the multiword flag
    def s_shift_tag_data
      
      # Shift a default tag if we support them
      if @df_valid and @l.peek(:default_tag)
        @l.shift(:default_tag)
        return :default_tag, nil, nil, nil, "Df"
      end

      # Tag category
      str = ""
      tag_cat = [@l.shift(:letter)]
      tag_cat << @l.shift(:num)

      # Build str
      str = tag_cat.join

      while(@l.peek(:num))
        tag_cat << @l.shift(:num)
        str += ".#{tag_cat.last}"
      end

      # Read affinity from -/= strings
      affinity = 0
      if(@l.peek(:affinity))
        stra = @l.shift(:affinity)
        str += stra

        affinity = stra.length
        affinity *= -1 if(stra =~ /^-+$/)

        @l.error("affinity must be between -3 and +3 (found #{affinity})") if affinity.abs > 3
      end

      # Read modifiers
      modifiers = []
      while(@l.peek(:modifier))
        m = @l.shift(:modifier)
        @l.error("duplicate modifier: #{m}") if modifiers.include?(m)
        modifiers << m
      end
      str += modifiers.join

      return :tag, tag_cat, modifiers, affinity, str
    end

    # Shift the end of string char.
    def s_shift_eos
      @l.shift(:eos)
    end

    # Validate the tag's categories against a taxonomy
    def s_valid_tag?(tag_cat, tree=@descriptions)

      # Read the next level down, return if we have hit the end
      level = tag_cat.shift
      return true unless level

      # Fallen off bottom of tree but still have items in tag_cat
      return false unless tree

      # Else read one level down
      if(tree[level])
        # return false unless tree[level]['c']
        found = s_valid_tag?(tag_cat, tree[level]['c'])

        # If we already have a description/name, pass straight through
        return found if found.is_a?(Array)

        # Else add one from this level
        return [true, tree[level]['name'], tree[level]['desc']] if found
      end

      return false
    end

    # Create a tag and check it against a taxonomy if one exists
    def s_create_tag(tag_cat, modifiers, affinity, multi_word = false, str = '')
      # Validate against internal list if set
      # If the taxonomy exists, get name and description
      name        = nil
      description = nil
      if validate?
        found, name, description = s_valid_tag?(tag_cat.dup) 
        @l.error("tag not in taxonomy: #{str}") unless found
      end

      return SemTag.new(tag_cat, modifiers, affinity, multi_word, string: str, name: name, desc: description)
    end

    ## =======================================================
    # RD parser below.
    # This parser tokenises on-the-fly using regexp.

    # Multiple space-separated compound tags
    #
    # <compound tag> [ <space> <compound tag> ]* <multi_word_modifier>
    def p_tags
      p_compound_tag
      while @p.peek(/^\s+/) && @p.peek(/^./)
        @p.consume(/^\s+/, :also, 'whitespace')
        p_compound_tag
      end
    end

    # A compound tag is:
    #
    # <tag> [ "/" <tag> ]*
    def p_compound_tag
      p_tag
      while(@p.peek(/^\//))
        @p.consume(/^\//, :compound, 'forward slash')
        p_tag
      end

      p_multi_word_modifier if @p.peek(/^\[i/)
    end

    # A tag is:
    #
    # <dftag> | ( <letter> <number> [ <dot> <number> ]* <modifier>* )
    def p_tag

      # If Df tags are valid, detect one
      if @df_valid && @p.peek(/^Df/)
        p_df_tag
        return
      end

      # Read the category classification
      p_letter
      p_num

      # Full stack of dot-separated numbers
      while(@p.peek(/^\./))
        p_dot
        p_num
      end

      # Plusses and minuses
      p_affinity_marker if @p.peek(/^[\-+]/)

      # Any modifiers
      while !@p.peek(/^(\/|\s|\[)/) && @p.peek(/^./)
        p_modifier
      end

    end

    # A Df tag is
    #
    # "Df"
    def p_df_tag
      @p.consume(/^Df/, :default_tag, 'default tag')
    end

    # An affinity marker is
    #
    # "+"* | "-"*
    def p_affinity_marker
      @p.consume(/^(-+|\++)/, :affinity, 'affinity marker')
    end

    # A modifier is
    #
    # one of f,m,n,c,i,@,%
    def p_modifier
      @p.consume(/^[fmnci@%]/, :modifier, 'modifier'){ |m| m.downcase }
    end

    # A multi_word modifier is
    #
    # "[i"
    def p_multi_word_modifier
      @p.consume(/^\[i/, :multi_word, 'multiword modifier'){ |m| m.downcase }
    end

    # A dot is "."
    def p_dot
      @p.consume(/^\./, nil, 'dot')
    end

    # A number is [0-9]+
    def p_num
      @p.consume(/^[0-9]+/, :num, 'number'){ |n| n.to_i }
    end

    # A letter is [A-Z]
    def p_letter
      @p.consume(/^[A-Z]/, :letter, 'uppercase letter'){ |l| l.upcase }
    end

    # End of string is
    # ^$
    def p_eos
      @p.consume(/^$/, :eos, 'end of string')
    end

  end

end


