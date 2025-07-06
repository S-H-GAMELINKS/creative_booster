#!/usr/bin/env ruby

require_relative 'models'

hashtags = Hashtag.all.order(:name).pluck(:name)

File.open('hashtags.txt', 'w') do |file|
  hashtags.each do |name|
    file.puts name
  end
end

puts "hashtags.txt に #{hashtags.count} 件のハッシュタグを出力しました"