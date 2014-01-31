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

# Handles requests from the BLC form.
class FormApplication

  # Timeout in minutes
  MAX_TIMEOUT           = 120

  # Where to find web erb templates
  TEMPLATE_DIR          = './templates'
  LANGUAGE_REF_DIR      = 'references'

  # Where to put output files
  OUTPUT_DIR            = './output'

  # Where to store registry of worker's word completions
  AMT_WORKER_WORD_LIST  = 'amt_worker_words.yml'

  require 'erb'             # templating
  require 'cgi'             # escaping only
  require 'digest/md5'      # filenames
  require 'json'            # tag list parsing
  require 'yaml/store'      # AMT word list and output
  require 'securerandom'    # UUIDs
  require 'base64'          # Word argument
  require 'usastools'       # Tag checking etc.

  # List valid actions for internal use
  VALID_ACTIONS = %w{form add check_worker_id go}


  # Initialise with a lexicon directory
  def initialize(lexicon_dir = nil)
    @tagparser        = USASTools::SemTag::Parser.new(true)
    @lexicons         = load_lexicons(lexicon_dir) if lexicon_dir
    @valid_languages  = Dir.glob(File.join(TEMPLATE_DIR, LANGUAGE_REF_DIR, '*.erb')).map{ |x| File.basename(x).gsub(/\.erb$/, '') }
  end


  # Is the action valid at this time?
  def valid?(action)
    self.respond_to?(action.to_sym) && VALID_ACTIONS.include?(action)
  end


  # Check if a worker has done a word before
  def check_worker_id(args)
   
    # Load params
    worker = args['worker'].to_s.strip
    word   = args['word'].to_s.strip.downcase

    # Load hash of who has done what
    worker_words  = YAML::Store.new(AMT_WORKER_WORD_LIST)
    previous_work = worker_words.transaction do (worker_words[worker] && worker_words[worker].include?(word)) end

    return compose_template('previous_work', binding) if previous_work
    return compose_template('no_previous_work', binding)
  end


  # Show a debug form
  def go(args)
    return compose_template('go', binding)
  end


  # Serve the form
  def form(args)
    word = '';
    begin
      word = Base64.urlsafe_decode64(args['word'])
      word.downcase!  ## XXX: optional...
    rescue
      raise 'No word (or invalid format)'
    end
    raise 'No word' if word.to_s.length == 0
    source = args['source'].to_s.gsub(/[^A-Za-z0-9]/, '').downcase       # Is this from AMT?

    # Load language
    language = @valid_languages[0]
    if(args['lang'])
      language = args['lang'].to_s.gsub(/[^A-Za-z0-9]/, '').downcase       # What references do we show?
      raise 'Invalid language.' unless @valid_languages.include?(language)
    end

    # Compute timeout "safely"
    timeout = args['timeout'].to_s.to_i # timeout in ms
    timeout = 0 if timeout < 0 || timeout > MAX_TIMEOUT

    # Load tags, if we have a lexicon
    tags    = []
    tags    = load_tags(language, word) if @lexicons[language]

    refs_html = compose_template(File.join(LANGUAGE_REF_DIR, language), binding)
    return compose_template('form', binding)
  end


  # Store the results and serve a receipt
  def add(args)
    # Check input is valid
    receipt_code, fail_reason = handle_input(args['word'].to_s.strip.downcase,
                                             args['from'].to_s.strip.downcase, 
                                             args['tags'].to_s.strip, 
                                             args['time'].to_s.strip.downcase,
                                             args['worker'].to_s.strip,
                                             args['lang'].to_s.strip.downcase)
    
    # Success page else failure page
    return compose_template('receipt', binding) if receipt_code
    return compose_template('fail', binding)
  end


  private


  # Load all lexicons from a directory and return them
  # indexed by basename
  def load_lexicons(dir)
    require 'usastools/lexicon'

    puts "Loading lexicons from #{dir}..."
    pl = USASTools::Lexicon::Parser.new(
      {semtag_parser: USASTools::SemTag::Parser.new(true, lambda{|*_| return true}, lambda{|*_| return true})}, 
      {}, 
      {
        case_sensitive: false,
        error_cb: lambda{ |line, msg, str|
          $stderr.print " [E]#{line ? " line #{line} :--" : ''} #{msg}  \r"
          return true } 
      }

    )

    lexicons = {}
    Dir.glob( File.join(dir, '*_sw.usas') ).each do |fn|
      basename = File.basename(fn).gsub(/_sw\.usas/, '')
      puts " - #{basename}..."
      lexicons[basename] = pl.parse( fn )
    end

    puts "Loaded #{lexicons.length} lexicon[s] (#{lexicons.keys.join(', ')})"
    return lexicons
  end


  # Using a lexicon, return a hash to be written into the page code
  def load_tags(language, word)
    return [] unless @lexicons[language]
    selection = []

    # Find tags for all senses
    tags = []
    @lexicons[language].get_senses(word).each{ |s| tags += @lexicons[language].get(word, s) }

    # build selection list from tags
    tags.each do |t|
      t = t.tags[0] if t.is_a?(USASTools::SemTag::CompoundSemTag)
      
      selection << {prefix:   t.stack.join('_'),
                    name:     t.name,
                    positive: t.affinity >= 0
      }
    end

    return selection.uniq
  end


  # Parse input and save to disk (or return an error)
  def handle_input(word, source, tags_field, time_field, worker=nil, lang=nil)
    return nil, 'Invalid word returned!' if !check_string(word)

    tags = nil
    begin
      tags = parse_tag_JSON(tags_field)
    rescue StandardError => e
      return nil, "Error parsing JSON: #{e}"
    end
    return nil, 'Invalid JSON submitted' if !tags
    return nil, 'You must select at least one tag' if tags[:tags].length == 0

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

    # Write the submission into the existing list
    submissions = YAML::Store.new(word_filepath)
    submissions.transaction do submissions[uuid] = tags end

    # Lastly, maintain worker word list if worker ID is provided
    set_worker_word(worker, word) if(worker && worker.length > 0)

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
    raise 'No order information'          unless obj['order'].is_a?(Array)
    raise 'No tag information'            unless obj['selection'].is_a?(Hash)


    # Somewhere to store 'clean' copies of the data
    out_of_order_tags = {}

    # Check formats.
    obj['selection'].each{|k, v|

      # Check formats
      raise "No prefix for item #{k}"     unless v['prefix'].is_a?(String)
      raise "No name for item #{k}"       unless v['name'].is_a?(String)
      raise "No positivity for item #{k}" unless !!v['positive'] == v['positive']

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
      out_of_order_tags[v['prefix']] = tag
    }


    # Add to a hash in-order.
    hash = {}
    hash[:tags] = []
    obj['order'].each{|prefix|
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
    worker_words = YAML::Store.new(AMT_WORKER_WORD_LIST)
    worker_words.transaction do
        # Set to array if she be not exist and add the word to the list
        worker_words[worker] = [] unless worker_words[worker]
        worker_words[worker] << word if(!worker_words[worker].include?(word))
    end
  end


  # ----------------------------------------------------------------------------
  # Utilities for templates
  #
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


# ==========================================================================
# Entry point
#


# Load various paths from command line
LEXICON_ROOT = ARGV[0] || './lexicons'
STATIC_ROOT  = ARGV[1] || './themes/ucrel'
DATA_ROOT    = './js-data'


# Create a new form handling deely.
application = FormApplication.new( LEXICON_ROOT )



# Stack up some servlets for webrick
servlets = { 
             '/'       => {cls: FormServer, args: [application]},
             '/static' => {cls: WEBrick::HTTPServlet::FileHandler, args: [STATIC_ROOT]},
             '/data'   => {cls: WEBrick::HTTPServlet::FileHandler, args: [DATA_ROOT]}
           }


# Hook the servlets and start listening
#
# Sigint to close
s = Server.new(servlets)
s.start

