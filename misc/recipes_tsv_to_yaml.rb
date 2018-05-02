require "yaml"

tsv, yaml = *ARGV
lines = File.readlines(tsv)
lines.shift

recipes = lines.map{|l|
  items = l.split("\t")
  [
    items[0],
    items[13],
    items[14].sub(/\.jpg\z/, ""),
    %w{onion tomato potato paprika eggplant beef pork chicken banana corn}.zip(items[1, 10]).map{|name, e| e == "1" ? name : nil }.compact.uniq,
    %w{ spring summer fall winter }[items[12].to_i - 1],
    %w{ morning noon evening }[items[11].to_i - 1],
  ]
}

open(yaml, "w") do |f|
  f.puts(YAML.dump(recipes))
end
