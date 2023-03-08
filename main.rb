require 'mastodon'
require 'clockwork'
require 'dotenv'
require 'logger'

include Clockwork

# 環境変数の読み込み
Dotenv.load

# ロガーの生成
logger = Logger.new(STDERR)

# 定期ジョブ実行用のハンドラ
handler do |job|
  puts "Running #{job}"
end

# 30分ごとにジョブを実行
every(30.minutes, 'boost.job') do 
  client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_URL'], bearer_token: ENV['ACCESS_TOKEN'])
  keywords = ENV['KEYWORDS'].split(',')
  keywords.each do |keyword|
    begin
      client.hashtag_timeline(keyword, limit: 100).each do
        client.reblog(_1.id)
        client.favourite(_1.id)
      end
    rescue => e
      puts e
    end
  end
end
