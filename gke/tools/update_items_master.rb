# coding: utf-8

require "yaml"
require_relative "../pull"

class Datastore
  def put_item(name, price, location)
    entity = Google::Cloud::Datastore::Entity.new
    entity.key = Google::Cloud::Datastore::Key.new("Item", name)
    entity["name"] = name
    entity["price"] = price
    entity["location"] = location
    @dataset.save(entity)
  end
end

def main(project, items)
  datastore = Datastore.new(project)

  items.each do |name, price, location|
    datastore.put_item(name, price, location)
  end
end

if $0 == __FILE__
  config, tsv = ARGV

  config = YAML.load_file(config)
  items = File.readlines(tsv).map{|l| l.chomp.split("\t") }
  main(config["project"], items)
end
