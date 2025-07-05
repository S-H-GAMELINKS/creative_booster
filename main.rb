require 'mastodon'
require 'dotenv'
require 'logger'
require_relative 'models'

# 環境変数の読み込み
Dotenv.load

# ロガーの生成
logger = Logger.new(STDERR)

# 初期ハッシュタグをデータベースに移行
if ENV['KEYWORDS']
  ENV['KEYWORDS'].split(',').each do |keyword|
    Hashtag.find_or_create_by(name: keyword.strip)
  end
end

client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_URL'], bearer_token: ENV['ACCESS_TOKEN'])

# データベースからアクティブなハッシュタグを取得
hashtags = Hashtag.active.pluck(:name)

if hashtags.empty?
  logger.warn "No active hashtags found in database"
  next
end

hashtags.each do |hashtag|
  begin
    client.hashtag_timeline(hashtag, limit: 10).each do |status|
      # ブーストとお気に入り
      client.reblog(status.id)
      client.favourite(status.id)

      # 投稿からハッシュタグを抽出して学習
      if status.tags && status.tags.any?
        puts status.tags.map(&:name)
        status.tags.each do |tag|
          tag_name = tag.name.downcase
          # 新しいハッシュタグをデータベースに追加
          unless Hashtag.exists?(name: tag_name)
            Hashtag.create!(name: tag_name)
            logger.info "New hashtag learned: #{tag_name}"
          end
        end
      end
    end
  rescue => e
    logger.error "Error processing hashtag #{hashtag}: #{e.message}"
  end
end
