

# Mixin for parsers.
module USASTools


  class RegexParser

    attr_accessor :stack, :position, :str

    # Reset the parser state.
    #
    # Called when any of the parse_* methods are below
    def initialize(str, error_callback = nil, newline = /\r?\n/, history_size = 10)
      # Settings
      @line_chomp_rx  = /.+(#{newline.inspect[1..-2]})(?<line>.*)$/m
      @error_callback = error_callback

      # State
      @str      = str
      @stack    = []
      @history  = HistoryBuffer.new(history_size.to_i)

      @position = 1
      @line     = 1
    end

    ## =======================================================
    # RD parser below.
    # This parser tokenises on-the-fly using regexp.

    # If the regex matches, consume the beginning of the
    # parse string.  If a type is given, it goes onto the stack,
    # else it is thrown away.
    def consume(expected=/.*/, type=nil, type_string=nil, &block)
      # puts "#{@line}:#{@position} -> #{expected.inspect} / #{type}, got #{@str[0..10]}"

      # Match from regex
      if(m = expected.match(@str))
        length     = m[0].length      # Get length from match
        str        = @str[0..length-1]  # Take from start of string
        @str       = @str[length..-1]   # Remove start of string
        @position += length           # Increment position
        @history << str

        # Count new lines
        if str =~ @newline 
          @line     += str.scan(@newline).length
          m          = @line_chomp_rx.match(str)
          @position = m[:line].to_s.length
        end

        # Only place on stack if we wish to keep the thing
        if(type)
          push(type, str, &block)
        end
      else
        type_string = "<#{type}>" unless type_string || type.nil?
        error("expected #{type_string || '<no type>'} (rule: #{expected.inspect}) between '#{@history.data.join.reverse[0..10].reverse}' and '#{@str.to_s[0..10]}'")
        # Callback returned true, skip over token
        # We don't actually know how long the 'token' is due to using regex,
        # so consume a single char only.
        @position += 1
        @str = (@str || '')[1..-1]
      end
    end

    # Add something to the stack with a given type
    def push(type, value = nil)
      value = yield(value) if block_given?
      @stack << {type: type, val: value}
    end

    # Peek at the string, matching it with a given regex
    def peek(rx)
      return rx.match(@str)
    end

    # Report an error
    def error(msg)
      if !@error_callback || (@error_callback != nil && !@error_callback.call(@line, @position, msg))
        raise ParseError, "line #{@line}:#{@position} : #{msg}"
      end
    end

  end


  # Mixin for semantic analysis,
  # which is essentially the inverse of the
  # parsing stage
  class RegexAnalyser

    # Reset the analyser and set its stack
    #
    # Optional if RegexParser is also mixed in, 
    # since they use the same member variable, @stack
    def initialize(stack = [], error_callback = nil)
      @error_callback = error_callback
      @stack          = stack
      @position       = 0
      @history        = nil
    end

    # Peek at the first item in the token queue,
    # returning true if the type is the same as the expected one
    # given
    def peek(type)
      @stack.first != nil && @stack.first[:type] == type
    end

    # Shift an item off the front of the array,
    # Throws an exception if the type is not equal
    # to the argument given.
    def shift(type_expected)
      item = @stack.shift
      @position += 1

      # Return nil if the item is nil.
      # This catches the end of any errors
      item = {type: nil, val: nil} if !item

      # Throw an error or use the callback if the types differ
      if item[:type] != type_expected
        last_str = @history ? "'#{@history[:val]}' (#{@history[:type]})" : '<start>'
        error("expected type '#{type_expected}' between tokens #{last_str} and '#{item[:val]}' (#{item[:type]})")
        if @stack.length > 0
          # Skip over only if the item actually exists.
          # This prevents us from infinitely recursing if the error callback always
          # tells us to continue.
          return shift(type_expected)
        else
          return nil
        end
      end

      # All is well, return item
      @history = item
      return item[:val]
    end

    # Send an error to the callback, or throw it, depending on behaviour
    def error(msg)
      if !@error_callback || (@error_callback != nil && !@error_callback.call(@position, msg))
        raise ParseError, "token #{@position}: #{msg}"
      end
    end

  end


  class ParseError < StandardError
  end


  # A circular queue used to store the last 'n' tokens by the
  # parser.  This is ONLY used for nicer output, and is entirely
  # superfluous.
  class HistoryBuffer
    
    attr_reader :size, :data

    def initialize(size)
      @size = size
      @data = []
    end

    def <<(item)
      @data << item
      @data = @data[1..-1] if @data.size > @size
    end 

  end

end


