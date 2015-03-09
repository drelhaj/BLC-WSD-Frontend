

module USASTools
  
  require 'usastools/semtag'

  RESOURCE_DIR = 'resources'
  DEFAULT_TAXONOMY_FILENAME = 'usas.yml'

  def USASTools::default_sem_taxonomy
    USASTools::SemTag::Taxonomy.new
  end


  def USASTools::gem_root
    # Current file is /home/you/code/your/lib/gem.rb
    File.expand_path('../', File.dirname(__FILE__))
  end



end


