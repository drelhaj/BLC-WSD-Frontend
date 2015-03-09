



# # ###########################################################################
# # Lexicon parser test
# #

# require 'usastools/lexicon'

# TEST_LEXICON = "./test_data/lexicon.c7"


# pl = USASTools::Lexicon::Parser.new(case_sensitive: false)
# l = pl.parse( TEST_LEXICON, Encoding::ISO_8859_1
#             )


# puts "==> #{l}"
# puts "word: #{l.word_count}"
# puts "senses: #{l.sense_count}"
# puts "tags: #{l.semtag_count}"


# ###########################################################################
# # Semtag parser test

# require 'usastools/semtag'


# # Informal test pack
# test = []
# test << "A1.1.1"
# test << "S7.1/S2mf"
# test << "G3"
# test << "K5.1"
# test << "S7.1+"
# test << "S7.1++"
# test << "S7.1+++"
# test << "S7.1-"
# test << "S7.1--"
# test << "S7.1---"
# test << "S2mf"
# test << "Q4.1[i I1/K5.1%[i"
# test << "Q4.1++/K5.1mf I1/K5.1%"


# p = USASTools::SemTag::Parser.new(true,
#   lambda{ |line, pos, msg|
#     puts "Parse error line: #{line} char: #{pos} --- #{msg}"
#     true
#   },
#   lambda{ |pos, msg|
#     puts "Semantic error: token ##{pos} : #{msg}"
#     true
#   }            
# )


# test.each{|t|
#   puts "\n===\n#{t}"
#   tags = p.parse_tags(t)

#   puts " Result: '" + tags.map{|t| t.to_s}.join(" ") + "'"
#   # puts " Valid?   #{p.valid?(tags, true)}"
#   #puts "Augment:  #{p.augment(tags)}"
# }


# puts "Interactive (enter some tags)"
# while(s = gets)
#   s.strip!
#   puts "-> #{s}"
#   tags = p.parse_tags(s)
#   puts "   #{tags.map{|t| t.to_s}.join(' ')}"
# end

# ###########################################################################
# # Semtag edit distance test 


# require 'usastools/semtag'

# # Informal test pack
# test = []
# test << "A1.1.1"
# test << "G3"
# test << "K5.1"
# test << "S7.1+fm"
# test << "S7.1++m"
# test << "S7.1---mf@"
# test << "S2mf"


# p = USASTools::SemTag::Parser.new(true)
# # p = USASTagParser.new();

# test.map!{|t| p.parse_tag(t) }


# # require 'pry'
# # pry binding

# test.length.times{|i|
#   test.length.times{|j|
#     comparison = USASTools::SemTag::Metrics.edit_distance_tag(test[i], test[j])
#     puts "#{test[i]} =/= #{test[j]} == #{comparison}"
#   }
# }


# #### Set comparison

# a = [0, 1, 2, 3, 4]
# b = []

# a.map!{|x| test[x]}
# b.map!{|x| test[x]}

# diff = USASTools::SemTag::Metrics.edit_distance_tags(a, b)
# puts "\n#{a.join(" ")}\n#{b.join(" ")}\n== #{diff}"

# ###########################################################################
# Find similar tags from lexicon (test of similarity)

# TEST_LEXICON = "./test_data/swlexicon.usas"

# require 'usastools/semtag'
# require 'usastools/lexicon'


# # Create error callbacks for the parser
# semtag_parse_cb = lambda do |line, pos, msg|
#   # $stderr.puts "Syntax error on line #{line}:#{pos} :-- #{msg}"
#   return false  # Continue
# end
# semtag_sem_cb = lambda do |pos, msg|
#   # $stderr.puts "Semantic error: #{pos} #{msg}"
#   # sleep(1)
#   return false
# end

# # Create the parser
# p   = USASTools::SemTag::Parser.new(nil, semtag_parse_cb, semtag_sem_cb)

# # Create error callbacks for the lexicon loader
# lex_error_cb = lambda do |line, msg, str|
#   $stderr.puts "[E] line #{line} :-- #{msg}" # ('#{str}') (continuing)"
#   return  true 
# end

# # put the parser into the lexicon parser
# pl  = USASTools::Lexicon::SingleWordParser.new(true, semtag_parser: p, error_cb: lex_error_cb)

# puts "Loading lexcicon #{TEST_LEXICON}..."
# l   = pl.parse( TEST_LEXICON, Encoding::ISO_8859_1 )

# similarity = {}
# input_tags = p.parse_tags(ARGV[0])


# l.each_word_sense{|word, sense, tags|
#   puts("#{word}")
#   similarity["#{word}_#{sense}"] = USASTools::SemTag::Metrics.edit_distance_tags(input_tags, tags, 0.1)
# }
# print "\n"


# sorted = similarity.sort_by{ |word, diff| diff }
# sorted[0..10].each{|k|
#   k, v = k
#   puts "#{input_tags.join(" ")} =/= #{k} => #{v}" 
# }


# ###########################################################################
# Multi-word lexicon parsing
# TEST_LEXICON = "./test_data/sw_sem_lexicon.usas"

# require 'usastools/semtag'
# require 'usastools/lexicon'


# # Create error callbacks for the parser
# parse_cb = lambda do |line, pos, msg|
#   # $stderr.puts "Syntax error on line #{line}:#{pos} :-- #{msg}"
#   return false  # false == don't continue
# end
# sem_cb = lambda do |pos, msg|
#   # $stderr.puts "Semantic error: #{pos} #{msg}"
#   # sleep(1)
#   return false 
# end

# # Create the parser
# p   = USASTools::SemTag::Parser.new(nil, parse_cb, sem_cb)

# # Create error callbacks for the lexicon loader
# lex_error_cb = lambda do |line, msg, str|
#   $stderr.puts "[E]#{line ? " line #{line} :--" : ''} #{msg}" # ('#{str}') (continuing)"
#   return true 
# end

# pp = USASTools::Pattern::Parser.new(parse_cb, sem_cb)

# # put the parser into the lexicon parser
# pl  = USASTools::Lexicon::SingleWordParser.new(case_sensitive: true, order_sensitive: true, 
#                                                pattern_parser: pp, semtag_parser: p, error_cb: lex_error_cb)

# puts "Loading lexcicon #{TEST_LEXICON}..."
# # version, type = USASTools::Lexicon::Parser.read_header(TEST_LEXICON)
# # puts "Lexicon info: version: #{version} type: #{type}-word"
# # l   = pl.parse( TEST_LEXICON, Encoding::ISO_8859_1 )
# l   = pl.parse( TEST_LEXICON )

# l.write( $stdout )
#         # TEST_LEXICON + ".out" )




# ###########################################################################
# Single-word lexicon merging 
left_lex = ARGV[0]
right_lex = ARGV[1]

require 'usastools/semtag'
require 'usastools/lexicon'


# Create error callbacks for the parser
parse_cb = lambda do |line, pos, msg|
  # $stderr.puts "Syntax error on line #{line}:#{pos} :-- #{msg}"
  return false  # false == don't continue
end
sem_cb = lambda do |pos, msg|
  # $stderr.puts "Semantic error: #{pos} #{msg}"
  # sleep(1)
  return false 
end

# Create the parser
p   = USASTools::SemTag::Parser.new(nil, parse_cb, sem_cb)

# Create error callbacks for the lexicon loader
lex_error_cb = lambda do |line, msg, str|
  $stderr.puts "[E]#{line ? " line #{line} :--" : ''} #{msg}" # ('#{str}') (continuing)"
  return true 
end

pp = USASTools::Pattern::Parser.new(parse_cb, sem_cb)

# put the parser into the lexicon parser
opts = {
  case_sensitive: true, order_sensitive: true, 
  pattern_parser: pp, semtag_parser: p, error_cb: lex_error_cb
}
pl  = USASTools::Lexicon::Parser.new({}, opts, opts)

puts "Loading lexcicon #{left_lex}..."
version, type = USASTools::Lexicon::ParserTools.read_header(left_lex)
puts "Lexicon info: version: #{version} type: #{type}-word"
# l   = pl.parse( TEST_LEXICON, Encoding::ISO_8859_1 )
left   = pl.parse( left_lex )

# puts "Loading lexicon #{right_lex}..."
# version, type = USASTools::Lexicon::ParserTools.read_header(right_lex)
# puts "Lexicon info: version: #{version} type: #{type}-word"
# right = pl.parse( right_lex )

# # TODO: versions, types must agree

# puts "Lexicon size pre-merge: #{left.size} / #{right.size}"

# left.merge_lexicon(right, in_other: :other, in_self: :self, in_both: :left)

puts "Lexicon size: #{left.size}"

# left.write($stdout, true)

