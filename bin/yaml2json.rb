#!/bin/env ruby

if ARGV.length < 1
  $stderr.puts "USAGE: #{$0} YAML_FILE"
  exit(1)
end

require 'yaml'
require 'json'


# Open file handle
fin = File.open(ARGV[0], 'r')

puts JSON.pretty_generate( YAML.load(fin) )



fin.close


