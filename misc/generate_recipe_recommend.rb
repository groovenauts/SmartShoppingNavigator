# encoding: utf-8
# frozen_string_literal: true

def recipes_info(tsv)
  recipes = File.readlines(tsv).map{|l| l.split("\t") }
  recipes.shift
  data = recipes.map{|l|
    [
      l[0],
      l[13],
      l[14].sub(/\.jpe?g\z/, ""),
      l.zip([nil, "onion", "tomato", "potato", "paprika", "eggplant", "beef", "pork", "chicken", "banana", "corn", nil, nil, nil, nil, nil]).map{|i, n| i == "1" ? n : nil }.compact,
      [nil, "spring", "summer", "fall", "winter"][l[12].to_i],
      [nil, "morning", "noon", "evening"][l[11].to_i],
    ]
  }
end

if __FILE__ == $0
require "yaml"
tsv, yaml = ARGV
open(yaml, "w") do |f|
  f.puts recipes_info(tsv)
end
end

