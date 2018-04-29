# encoding: utf-8
# frozen_string_literal: true

def cart2vec(cart)
  stuffs = %w{
    onion
    tomato
    potato
    paprika
    eggplant
    beef
    pork
    chicken
    banana
    corn
  }
  10.times.map{|i|
    cart.include?(stuffs[i]) ? 1 : 0
  }
end

def cart2history(cart)
  history = [cart, cart + ["end"]]
  8.times do
    oldest = history.first.dup
    if oldest.size > 0
      meat = oldest & ["beef", "pork", "chicken"]
      if meat.empty? or rand() < 0.1
        oldest.delete_at(rand(oldest.size))
      else
        oldest.delete(meat.sample)
      end
    end
    history.unshift(oldest)
  end
  history
end

def pos2training_data(pos)
  cart, season, period = *pos
  history = cart2history(cart)
  rows = []
  (history.size-5+1).times do |i|
    recent = history[-5-i, 5]
    if recent.last.empty?
      break
    end
    serise = recent[0, 4]
    label = (recent[-1] - recent[-2])[0]
    serise.map!{|cart| cart2vec(cart) }
    rows << [serise, season, period, label]
  end
  rows.reverse
end

def recipes2training_data(recipes)
  data = recipes.map{|l|
    [
      l.zip([nil, "onion", "tomato", "potato", "paprika", "eggplant", "beef", "pork", "chicken", "banana", "corn", nil, nil, nil, nil, nil]).map{|i, n| i == "1" ? n : nil }.compact,
      [nil, "spring", "summer", "fall", "winter"][l[12].to_i],
      [nil, "morning", "noon", "evening"][l[11].to_i]
    ]
  }
  rows = []
  data.each do |pos|
    rows += pos2training_data(pos)
  end
  rows
end

if __FILE__ == $0
tsv, csv = ARGV
recipes = File.readlines(tsv).map{|l| l.split("\t") }
recipes.shift
open(csv, "w") do |f|
  100.times do
    recipes2training_data(recipes).each do |row|
      f.puts(row.flatten.join(","))
    end
  end
end
end

