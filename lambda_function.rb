load_paths = Dir["/vendor/bundle/ruby/2.7.0/gems/**/lib"]
$LOAD_PATH.unshift(*load_paths)

require 'mastodon'

def lambda_handler(event:, context:)
  client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_URL'], bearer_token: ENV['ACCESS_TOKEN'])
  keywords = ENV['KEYWORDS'].split(',')

  keywords.each do |keyword|
    begin
      client.hashtag_timeline(keyword, limit: 1000).each do
        client.reblog(_1.id)
        client.favourite(_1.id)
      end
    rescue => e
      puts e
    end
  end
end