#!/usr/bin/env ruby


class Server

  require 'webrick'

  def initialize(servlets   = {'/' => WEBrick::HTTPServlet::FileHandler},
                 iface      = 'localhost', 
                 port       = 8080
                )
    @interface    = iface
    @port         = port
    @servlets     = servlets
  end

  def start
    # Process options from before
    opts = {Port: @port, Hostname: @interface}

    # Create the server
    server = WEBrick::HTTPServer.new(opts)

    @servlets.each do |mount, clsargs|
      cls, args = clsargs[:cls], clsargs[:args]
      server.mount(mount, cls, *args)
    end

    # Shutdown on signal
    trap 'INT' do server.shutdown end

    # Serve
    server.start
  end
end



# --------------------------------------------------------------------------

# Handles requests from the web side
class FormServer < WEBrick::HTTPServlet::AbstractServlet

  # Construct a new ActionServer with a given set of actions,
  # and some options for callbacks( such as http auth ).
  def initialize(server, app, opts = {})
    super(server)
    @app = app
  end

  # Handle a get or post request 
  def do_request(request, response)
    body = make_request(request)

    # Always 200.  A simplification, but fine for user
    # error messages.
    response.status           = 200
    response['Content-Type']  = 'text/html' 
    response.body             = body
  end

  alias :do_GET  :do_request
  alias :do_POST :do_request

  private

  # Handle a request to the server.
  # Called by get and post.
  def make_request(request)
    puts "\n\n"
    puts "==> Request, action='#{request.path}', params = #{request.query}..."

    action = request.path.to_s.split("/")[-1]

    if action && @app.valid?(action) then
      response = @app.send(action.to_sym, request.query)

      return response
    end

    return "Error: Unrecognised action: #{action}"
  rescue Exception => e
    $stderr.puts "*** [E]: #{e}\n#{e.backtrace.join("\n")}"
    return "Error: #{e}"
  end
end



# --------------------------------------------------------------------------

class FormApplication

  # Timeout in minutes
  MAX_TIMEOUT = 120 # Two hours

  # Where to find web erb templates
  TEMPLATE_DIR   = "./templates"
  LANGUAGE_REF_DIR = "references"

  # Where to put output files
  OUTPUT_DIR     = "./output"

  # Where to store registry of worker's word completions
  AMT_WORKER_WORD_LIST = "amt_worker_words.db"

  require 'erb'
  require 'cgi' # escaping only
  require 'digest/md5'  # filenames
  require 'json'
  require 'yaml'
  require 'securerandom' #UUIDs
  require 'base64'      # Word argument
  require 'usastools'   # Tag checking etc.

  # List valid actions for internal use
  VALID_ACTIONS = %w{form add check_worker_id go}

  # 
  def initialize(lexicon_filename = nil)
    @tagparser        = USASTools::SemTag::Parser.new(true)
    @lexicon          = load_lexicon(lexicon_filename) if lexicon_filename
    @valid_languages  = Dir.glob(File.join(TEMPLATE_DIR, LANGUAGE_REF_DIR, "*.erb")).map{ |x| File.basename(x).gsub(/\.erb$/, '') }
  end

  # Is the action valid at this time?
  def valid?(action)
    self.respond_to?(action.to_sym) && VALID_ACTIONS.include?(action)
  end

  # Check if a worker has done a word before
  def check_worker_id(args)
   
    # Load params
    worker = args["worker"].to_s.strip
    word   = args["word"].to_s.strip.downcase

    # Load hash of who has done what
    worker_words = {}
    worker_words = YAML.load(File.read(AMT_WORKER_WORD_LIST)) if File.exist?(AMT_WORKER_WORD_LIST)

    return compose_template("previous_work", binding) if(worker_words[worker] && worker_words[worker].include?(word))
    return compose_template("no_previous_work", binding)

  end

  # Show a debug form
  def go(args)
    return compose_template("go", binding)
  end

  # Serve the form
  def form(args)
    
    # word        = args["word"].to_s.strip.downcase      # The word, from the database
    word = '';
    begin
      word = Base64.urlsafe_decode64(args["word"])
      word.downcase!  ## XXX: optional...
    rescue
      raise "No word (or invalid format)"
    end
    raise "No word" if word.to_s.length == 0
    source = args["source"].to_s.gsub(/[^A-Za-z0-9]/, '').downcase       # Is this from AMT?

    # Load language
    language = @valid_languages[0]
    if(args["lang"])
      language = args["lang"].to_s.gsub(/[^A-Za-z0-9]/, '').downcase       # What references do we show?
      raise "Invalid language." unless @valid_languages.include?(language)
    end

    # Compute timeout "safely"
    timeout = args["timeout"].to_s.to_i # timeout in ms
    timeout = 0 if timeout < 0 || timeout > MAX_TIMEOUT

    # Load tags, if we have a lexicon
    tags    = []
    tags    = load_tags(word) if @lexicon

    refs_html = compose_template(File.join(LANGUAGE_REF_DIR, language), binding)
    return compose_template("form", binding)
  end

  # Store the results and serve a receipt
  def add(args)

    # Check input is valid
    receipt_code, fail_reason = handle_input(args["word"].to_s.strip.downcase,
                                             args["from"].to_s.strip.downcase, 
                                             args["tags"].to_s.strip, 
                                             args["time"].to_s.strip.downcase,
                                             args["worker"].to_s.strip.downcase,
                                             args["lang"].to_s.strip.downcase)
    
    # Success page
    if receipt_code
      return compose_template("receipt", binding)
    end
    
    # Failure page
    return compose_template("fail", binding)
  end


  private

  # Load a lexicon from en existing file
  def load_lexicon(filename)
    require 'usastools/lexicon'

    puts "Loading lexicon from #{filename}..."
    pl = USASTools::Lexicon::Parser.new(case_sensitive: false)
    return pl.parse( filename, Encoding::ISO_8859_1 )
  end

  # Using a lexicon, return a hash to be written into the page code
  def load_tags(word)
    selection = []

    # Find tags for all senses
    tags = []
    @lexicon.get_senses(word).each{ |s| tags += @lexicon.get(word, s) }

    # build selection list from tags
    tags.each do |t|
      t = t.tags[0] if t.is_a?(USASTools::SemTag::CompoundSemTag)
      
      selection << {prefix:   t.stack.join("_"),
                    name:     t.name,
                    positive: t.affinity >= 0
      }
    end

    return selection.uniq
  end

  # Parse input and save to disk (or return an error)
  def handle_input(word, source, tags_field, time_field, worker=nil, lang=nil)
    return nil, "Invalid word returned!" if !check_string(word)

    tags = nil
    begin
      tags = parse_tag_JSON(tags_field)
    rescue StandardError => e
      return nil, "Error parsing JSON: #{e}"
    end
    return nil, "Invalid JSON submitted" if !tags
    return nil, "You must select at least one tag" if tags[:tags].length == 0

    time = time_field.to_f / 60.0 / 1000.0 # convert to minutes
    # return nil, "Invalid timeout field" if time > MAX_TIMEOUT || time < 0

    # ---- validation done
    # Now augment tag information with time, date, etc.
    tags[:time]   = Time.now
    tags[:source] = source 
    tags[:word]   = word
    tags[:lang]   = lang if @valid_languages.include?(lang)
    
    # Now generate unique IDs and write to disk

    # Generate a filename by hashing the word
    word_filename = Digest::MD5.hexdigest(word)
    word_filepath = File.join(OUTPUT_DIR, word_filename)
    
    # Code to identify this transaction
    uuid          = SecureRandom.uuid()
    receipt_code  = "#{word_filename}#{uuid}"

    # Open the file and read its contents if it exists, else create a blank array
    submissions   = {}
    submissions   = YAML.load( File.read(word_filepath) ) if File.exist?(word_filepath)
  
    # Add in the list indexed by UUID for easy lookup
    submissions[uuid] = tags

    # Write to disk
    fout = File.open( word_filepath, 'w' )
    YAML.dump( submissions, fout )
    fout.close

    # ---- Lastly, maintain worker word list if provided
    if(worker && worker.length > 0)
      set_worker_word(worker, word)
    end

    # Return the code 
    return receipt_code, nil
  end

  # Parse JSON from the selection form.
  # Ensures that the json is internally-consistent,
  # and strips all of the data out into a new, ordered, list
  # of tags in descending order of preference.
  def parse_tag_JSON(json)
    obj = JSON.parse(json)
   
    # Each tag should have 
    #
    # prefix:   prefix,
    # name:     name,
    # positive: positive
    #
    # and each input json should have
    # { order: [ prefix, prefix...]
    #   selection: { prefix: {tag as above},
    #                prefix: {tag as above}
    #              }
    # }
    #
    raise "No order information"          unless obj["order"].is_a?(Array)
    raise "No tag information"            unless obj["selection"].is_a?(Hash)


    # Somewhere to store "clean" copies of the data
    out_of_order_tags = {}

    # Check formats.
    obj["selection"].each{|k, v|

      # Check formats
      raise "No prefix for item #{k}"     unless v["prefix"].is_a?(String)
      raise "No name for item #{k}"       unless v["name"].is_a?(String)
      raise "No positivity for item #{k}" unless !!v["positive"] == v["positive"]

      # Build the stack, converting numbers to numbers where possible
      # This is necessary because my parser is insanely strict
      stack = v['prefix'].split('_').map{ |x| x.to_s == x.to_i.to_s ? x.to_i : x.to_s }

      tag = USASTools::SemTag::SemTag.new(stack, [], !!v['positive'] ? 0 : -1)
      if @tagparser.valid?(tag)
        tag = @tagparser.augment(tag)
      else
        raise "Invalid tag: #{tag}"
      end

      # Put in main hash
      out_of_order_tags[v["prefix"]] = tag
    }


    # Add to a hash in-order.
    hash = {}
    hash[:tags] = []
    obj["order"].each{|prefix|
      hash[:tags] << out_of_order_tags[prefix.to_s]  
    }

    return hash
  end

  # Check a string to see if it is valid
  # Must be over 0 length and contain only
  # valid characters after removal of whitespace
  def check_string(str)
    str = str.strip

    return false if str =~ /<>{}/
    return false if str.length == 0

    return true
  end

  # Run a template
  def compose_template(name, bdg)
    puts "==> Composing template #{name}..."

    template = File.join(TEMPLATE_DIR, "#{name}.erb")
    raise "template '#{name}' does not exist" unless File.exist?(template)

    return ERB.new(File.read(template)).result(bdg)
  end

  # Check if a worker has done a word before
  def set_worker_word(worker, word)
    # puts "######### #{worker} ######## #{word}"

    # Load hash of who has done what
    worker_words = {}
    worker_words = YAML.load(File.read(AMT_WORKER_WORD_LIST)) if File.exist?(AMT_WORKER_WORD_LIST)

    # Set to array if she be not exist and add the word to the list
    worker_words[worker] = [] unless worker_words[worker]
    if(!worker_words[worker].include?(word))
      worker_words[worker] << word

      # Save to file
      fout = File.open(AMT_WORKER_WORD_LIST, 'w')
      YAML.dump(worker_words, fout)
      fout.close
    end
  end


  # ----------------------------------------------------------------------------
  # Utilities for templates
  #

  # HTML escaping
  def h(str)
    CGI.escapeHTML(str.to_s)
  end

  # Quote ("") escaping
  def q(str)
    str.to_s.inspect[1..-2]
  end

  # Pretty-print number with commas (integer only)
  def n(num)
    num.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
  end



end



# --------------------------------------------------------------------------







# ==========================================================================

# Create a new form handling deely.
application = FormApplication.new( ARGV[0] )


STATIC_ROOT = './static'
DATA_ROOT   = './js-data'


# Stack up some servlets for webrick
servlets = { 
             '/'       => {cls: FormServer, args: [application]},
             '/static' => {cls: WEBrick::HTTPServlet::FileHandler, args: [STATIC_ROOT]},
             '/data'   => {cls: WEBrick::HTTPServlet::FileHandler, args: [DATA_ROOT]}
           }



s = Server.new(servlets)
s.start

