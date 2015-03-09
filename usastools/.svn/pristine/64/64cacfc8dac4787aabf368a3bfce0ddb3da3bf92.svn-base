


module USASTools::SemTag

  require 'yaml'

  class Taxonomy
    def initialize(filename = nil)

      if !filename

        @tax = YAML.load( File.read( 
                                    File.join(USASTools::gem_root, 
                                              USASTools::RESOURCE_DIR, 
                                              USASTools::DEFAULT_TAXONOMY_FILENAME) ) )

      else
        @tax = YAML.load(File.read(filename))
      end


      # Check the format, roughly.
      raise "Taxonomy must be a YAML filename containing a hash" unless @tax.is_a?(Hash)
    end

    def method_missing(m, *args, &block)
      @tax.send(m, *args, &block)
    end
    
  end

end


