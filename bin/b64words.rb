#!/usr/bin/env ruby

# Base64 encodes words from one-word-per-line input on stdin,
# outputting url-safe b64-encoded words in a CSV alongside their
# progenitor
#
#

require 'csv'
require 'base64'      # Word argument

CSV($stdout) do |cout|

  # CSV header
  cout << %w{word b64word}

  $stdin.each_line do |line|
  
    line.chomp!
    line.strip!

    word = Base64.urlsafe_encode64(line)

    cout << [line, word]
  end


end
