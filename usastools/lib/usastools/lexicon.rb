

module USASTools::Lexicon

  # In-order list of lexicon file versions supported.
  VERSIONS = [:"1.0", :"1.1"]

  # Change encoding to match the file version being read
  FEATURES_BY_VERSION = {:"1.0" => {:encoding => Encoding.find('ISO8859-1'),
                                    :comments => false},
                         :"1.1" => {:encoding => Encoding.find('utf-8'),
                                    :comments => true}
  }

  # Magic number at the top of the lexicons
  HEADER_MAGIC_NUMBER = '##USASlexicon'

  # Return feature support for various items by version
  def self.get_feature_by_version(version, feature)
    return nil unless FEATURES_BY_VERSION[version]
    return FEATURES_BY_VERSION[version][feature]
  end

 
  # Base lexicon class extended by
  # SingleWordLexicon
  # and 
  # MultiWordLexicon
  class Lexicon
    
    attr_reader :version, :type

    def initialize(type, version = VERSIONS[-1])
      @type = type
      @version = version
    end

  end

  require 'usastools/lexicon/single_word'
  require 'usastools/lexicon/multi_word'
  require 'usastools/lexicon/parser'
end
