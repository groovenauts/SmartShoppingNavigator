# coding: utf-8

require "yaml"
require_relative "../pull"

def main(config, season, period, items)
  project = config["project"]
  recipes_yaml = config["recipes_yaml"]
  bucket_prediction_model = config["bucket_prediction_model"]
  gcs = GCS.new
  all_recipes_yaml = gcs.get_object_content(recipes_yaml)
  all_recipes = YAML.load(all_recipes_yaml)
  setting = { "season" => season, "period" => period }

  history = [[]]
  items.each do |s|
    history << history.last.dup + [s]
  end
  next_item = predict_next(project, bucket_prediction_model, history, setting)
  puts "History: #{history.inspect} -> Next: #{next_item}"
  objs = history.last.uniq
  if next_item != "end"
    key_item = next_item
  end
  items_to_recipes(all_recipes, objs, key_item).each do |i|
    puts "  #{i["title"]}: Must buy #{i["missingItems"]}"
  end
end

if $0 == __FILE__
  config, season, period, *items = ARGV

  if config
    config = YAML.load(File.read(config))
    config["recipes_yaml"] ||= "gs://gcp-iost-contents/recipes.yaml"
  else
    config = {}
    config["bucket_prediction_model"] = ENV["BUCKET_PREDICTION_MODEL"]
    config["recipes_yaml"] = ENV["RECIPES_YAML"] || "gs://gcp-iost-contents/recipes.yaml"
  end
  $stdout.sync = true
  $stderr.sync = true
  main(config, season, period, items)
end
