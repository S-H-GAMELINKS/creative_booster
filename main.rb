require 'mastodon'
require 'dotenv'
require 'logger'

# 環境変数の読み込み
Dotenv.load

# ロガーの生成
logger = Logger.new(STDERR)


client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_URL'], bearer_token: ENV['ACCESS_TOKEN'])
keywords = ENV['KEYWORDS'].split(',')

keywords.each do |keyword|
  begin
    client.hashtag_timeline(keyword, limit: 50000).each do
      client.reblog(_1.id)
      client.favourite(_1.id)
    end
  rescue => e
    puts e
  end
end
