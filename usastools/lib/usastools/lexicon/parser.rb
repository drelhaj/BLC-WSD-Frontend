

require 'usastools/semtag'
require 'usastools/lexicon'
require 'usastools/rx_parser'
require 'usastools/pattern'
require 'usastools/pattern/parser'

module USASTools::Lexicon

  # Parser for USAS lexicon files.
  #
  # Accepts UTF-8
  module ParserTools

    # Regexp used to detect a valid lexicon file.
    HEADER_RX           = /^#{Regexp.escape(HEADER_MAGIC_NUMBER)}_(?<version>[^_]+)_(?<type>(s|m))w(_.*)?(\s|$)/
    MAX_HEADER_LENGTH   = 256
    
    # Regexp string used to match comments
    COMMENT_REGEXP      = '^(#|//|/\*)'

    # Create a new parser.  Options are:
    #
    #   semtag_parser :  Override the default parser used for semtags
    #   comments      :  Set to false to disable comments in file (default is true)
    #   error_cb      :  Proc to be called with (error_msg, line_number, line) on each error.  Will
    #                    abort if this procedure returns false.
    def set_options(opts = {})  
      @comments       = (opts[:comments] == nil ? true : opts[:comments])
      @semtag_parser  = opts[:semtag_parser] || USASTools::SemTag::Parser.new(true)
      @error_callback = opts[:error_cb]
      @eof_marker     = opts[:eof_marker]
    end

    # Set the regexp used to parse a given line, in a given encoding
    def set_line_regexp_encoding(line_regexp, encoding = 'utf-8', options = 0)
      @line_regexp    = Regexp.new(line_regexp.encode(encoding), options)
      @comment_regexp = Regexp.new(COMMENT_REGEXP.encode(encoding), options)
    end

    # Read the header of a file to determine its type
    #
    # returns two things:
    #  version --- a version string
    #  type    --- :single or :multi
    # --or--
    #  nil if the file is invalid
    def self.read_header(filename_or_io, read_past_newline = true)
      fin = filename_or_io
      fin = File.open(filename_or_io, mode: 'r', encoding: 'utf-8', textmode: true) unless filename_or_io.is_a?(IO)

      # Read very conservatively to avoid hitting non-header
      # content which may not be in our encoding
      str = fin.read(HEADER_MAGIC_NUMBER.length)
      raise USASTools::ParseError, "file is not a lexicon: #{filename_or_io}" if str != HEADER_MAGIC_NUMBER

      while !(str =~ HEADER_RX) && str.length < MAX_HEADER_LENGTH do
        str += fin.read(1)
      end

      # Keep reading past the header.
      # Useful to ignore the header when parsing files
      if read_past_newline
        while !(str =~ /\n$/)
          str += fin.read(1)
        end
      end

      # Check header length
      raise USASTools::ParseError, "header too long (read #{MAX_HEADER_LENGTH} chars before giving up)" if str.length >= MAX_HEADER_LENGTH

      # Get groups
      m       = str.match(HEADER_RX)
      type    = (m[:type] == 'm' ? :multi : :single)
      version = m[:version].to_sym

      return version, type
    rescue StandardError => e
      raise USASTools::ParseError, "invalid header format: #{e}"
    ensure
      fin.close if fin && !filename_or_io.is_a?(IO)
    end

    # Parse a file and output a Lexicon.  Yields each valid line.
    #
    # filename: The filename to parse
    # encoding: The input file encoding, defaults to #Encoding.default_external
    def parse_body(filename_or_io, encoding, allow_comments = true, &blk)
      fin = filename_or_io
      fin = File.open(filename_or_io) unless filename_or_io.is_a?(IO)
     
      # Loop over each line
      count = 1 # Start at one to cover the header line
      fin.each_line do |line|

        # Say we are loading the encoding given
        line.force_encoding(encoding)
        line.chomp!
        line.strip!


        # If an EOF marker is given,
        # treat it like the end of the file and quit
        return true if @eof_marker && line == @eof_marker

        count += 1
        if @comment_regexp && line =~ @comment_regexp && allow_comments
          # comment
          # puts "COMMENT #{line}"
        elsif (m = @line_regexp.match(line))

          # Parse using m
          if (reason = yield(m)) != true
            error(reason, count, line)
          end

        else
          error("invalid line format", count, line)
          #: #{@line_regexp.inspect})", count, line) 
        end
        # add_line(lexicon, m[:word], m[:pos], m[:tags])

      end

      return true 
    ensure
      fin.close if fin && !filename_or_io.is_a?(IO)
    end


  # private

    # Handle an error using the callback, or throw it.
    def error(msg, count = nil, line = nil)
      if !@error_callback || (@error_callback and !@error_callback.call(count, msg, line))
        raise USASTools::ParseError, "#{msg} #{(count > -1) ? "on line #{count}" : ''}"
      end
    end

  end


  # Parses USAS' Single-word lexicon format
  class SingleWordParser
 
    # Include the parsing methods
    include USASTools::Lexicon::ParserTools

    # Allow people to access the version this parser is configured as
    attr_reader :version, :order_sensitive, :case_sensitive

    # This is converted to regex in the desired encoding later
    LINE_REGEXP_PATTERN = '^(?<word>[^\s]*)\s+(?<pos>[^\s]+)\s+(?<tags>.*)$'
    COMMENT_REGEXP      = '^(#|//|/\*)'

    def initialize(opts = {})
      set_options(opts)
      @case_sensitive  = (opts[:case_sensitive] == nil ? true : opts[:case_sensitive])
      @order_sensitive = (opts[:order_sensitive] == nil ? true : opts[:order_sensitive])
      @version        = version
    end

    
    def parse(filename, version=nil, type=nil)
      # Read the version and type from the header
      unless version && type
        begin
          version, type = ParserTools.read_header(filename)
        rescue USASTools::ParseError => pe
          error(pe, 1)
        end
      end

      # Check it's the right type of lexicon and quit even
      # if the error doesn't throw
      unless type == :single
        error("not a single-word lexicon (fatal): #{filename}") 
        return
      end

      # Set encoding to match
      encoding = USASTools::Lexicon.get_feature_by_version(version, :encoding)
      set_line_regexp_encoding(LINE_REGEXP_PATTERN, encoding)

      # Create a new lexicon and re-encode the line regex
      lexicon = USASTools::Lexicon::SingleWordLexicon.new(version)

      # Parse line-by-line
      last = nil
      out_of_order_count = 0
      parse_body(filename, encoding, USASTools::Lexicon.get_feature_by_version(version, :comments)) do |match|
        word, pos, semtags = match.captures

        # Clean up strings (newlines etc)
        word.strip!
        pos.strip!
        semtags.strip!

        # lowercase the word if not case sensitive
        word.downcase! unless @case_sensitive

        # return this
        rv = true
        # Parse the tags
        if @order_sensitive && last && word < last
          rv = "line out of order (further ordering errors squashed)" if out_of_order_count == 0
          out_of_order_count += 1
          last = word
        elsif semtags.length > 0
          begin
            semtags = @semtag_parser.parse_tags(semtags)
            semtags = [semtags] unless semtags.is_a?(Array)

            # Merge into the lexicon
            if lexicon.get(word, pos)
              rv = "duplicate entry: '#{word}' with pos '#{pos}'"
            else
              lexicon.merge_entry(word, pos, semtags)

              # Return true so the parser continues
              rv = true
            end
          rescue USASTools::ParseError => se
            rv = "tag parser: #{se}"
          end
        else
          rv = "no valid tags found"
        end

        last = word
        rv
      end

      error("#{out_of_order_count} line[s] out of order") if @order_sensitive && out_of_order_count > 0

      return lexicon
    end

  end



  # Parses USAS' Multi-word lexicon format
  class MultiWordParser
 
    # Include the parsing methods
    include USASTools::Lexicon::ParserTools
   
    LINE_REGEXP_PATTERN = '^\s*(?<pattern>([^\s^}]+_[^\s]+\s+|{[^}]+}\s+)+)(?<tags>.*)$'

    def initialize(opts = {})
      set_options(opts)
      @case_sensitive  = (opts[:case_sensitive] == nil ? true : opts[:case_sensitive])
      @pattern_parser  = opts[:pattern_parser] || USASTools::Pattern::Parser.new() 
    end

    
    def parse(filename, version=nil, type=nil)
      # Read the version and type from the header
      unless version && type
        begin
          version, type = ParserTools.read_header(filename)
        rescue USASTools::ParseError => pe
          error(pe, 1)
        end
      end

      # Check it's the right type of lexicon and quit even
      # if the error doesn't throw
      unless type == :multi
        error("not a multi-word lexicon (fatal): #{filename}")
        return
      end

      # Set encoding to match
      encoding = USASTools::Lexicon.get_feature_by_version(version, :encoding)
      set_line_regexp_encoding(LINE_REGEXP_PATTERN, encoding)

      # Create a new lexicon and re-encode the line regex
      lexicon = USASTools::Lexicon::MultiWordLexicon.new(version)

      # Parse line-by-line
      parse_body(filename, encoding, USASTools::Lexicon.get_feature_by_version(version, :comments)) do |match|
        pattern, semtags = match.captures

        # Clean up strings (newlines etc)
        pattern.strip!
        semtags.strip!

        # puts " pattern: |#{pattern}|"
        # puts " tags:    |#{semtags}|"

        # Parse the pattern
        pattern = parse_pattern(pattern)

        # Parse the tags
        rv = true
        if pattern.is_a?(String)
          rv = pattern
        elsif semtags.length > 0
          begin
            # Support Df tags
            semtags = @semtag_parser.parse_tags(semtags, true)
            semtags = [semtags] unless semtags.is_a?(Array)

            # Insert stuff.
            if lexicon.get(pattern)
              rv = "duplicate entry: #{pattern}"
            else
              lexicon.add(pattern, semtags)

              # Return true so the parser continues
              rv = true
            end
          rescue USASTools::ParseError => se
            rv = "tag parser: #{se}"
          end
        else
          rv = "no valid tags found"
        end

        rv
      end

      return lexicon
    end


  private
    
    # Parse the pattern.  Returns a string on failure
    def parse_pattern(str)

      pattern =  @pattern_parser.parse_multiword_pattern(str)
      return pattern

    rescue USASTools::ParseError => se
      return "pattern parser: #{se}"
    end


  end




  # A parser that can return either multi- or single-word lexicons depending
  # on input.
  class Parser

    # Create a new parser containing two others
    def initialize(opts = {}, multi_word_opts = {}, single_word_opts = {})
      @multi_word_parser  = opts[:multi_word_parser]  || MultiWordParser.new(multi_word_opts)
      @single_word_parser = opts[:single_word_parser] || SingleWordParser.new(single_word_opts)
    end

    # Returns a Lexicon of either SingleWord or MultiWord type.
    def parse(filename_or_io)
      
      # Load a file if necessary
      fin = filename_or_io
      fin = File.open(filename_or_io) unless filename_or_io.is_a?(IO)

      # Load the header
      version, type = ParserTools.read_header( fin )

      # Depending on the header, load a lexicon 
      parser = nil
      parser = @multi_word_parser  if type == :multi
      parser = @single_word_parser if type == :single

      return nil unless parser
      return parser.parse(fin, version, type)
    ensure
      fin.close if fin && !filename_or_io.is_a?(IO)
    end
  end



end




