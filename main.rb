require 'kisa'
require 'dotenv'
require 'logger'
require 'uri'
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

client = Kisa.new(url: ENV['MASTODON_URL'], headers: { 'Authorization' => "Bearer #{ENV['ACCESS_TOKEN']}" })

# データベースからアクティブなハッシュタグを取得
hashtags = Hashtag.active.pluck(:name)

if hashtags.empty?
  logger.warn "No active hashtags found in database"
end

hashtags.each do |hashtag|
  begin
    # このハッシュタグの最後に処理したステータスIDを取得
    last_status = HashtagLastStatus.find_by(hashtag_name: hashtag)
    since_id = last_status&.last_status_id

    # since_idを使用して新しい投稿のみを取得
    options = { limit: 100 }
    options[:since_id] = since_id if since_id

    statuses = client.hashtag_timeline(URI.encode_www_form_component(hashtag), limit: options[:limit], since_id: options[:since_id])

    if statuses.size == 0
      logger.info "No new statuses for hashtag: #{hashtag}"
      next
    end

    latest_status_id = nil

    statuses.each do |status|
      # 最新のステータスIDを記録（最初の要素が最新）
      latest_status_id ||= status['id']
      # 既にリブログ済みかチェック
      if RebloggedStatus.exists?(status_id: status['id'])
        logger.info "Status #{status['id']} already reblogged, skipping"
        next
      end

      # ブーストとお気に入り
      client.boost(status['id'])
      client.favourite(status['id'])

      # リブログ履歴を保存
      status_hashtags = status['tags'] ? status['tags'].map { |tag| tag['name'].downcase } : []
      RebloggedStatus.create!(
        status_id: status['id'],
        hashtags: status_hashtags
      )

      logger.info "Reblogged status #{status['id']} with hashtags: #{status_hashtags.join(', ')}"
    end

    # 最新のステータスIDを保存
    if latest_status_id
      if last_status
        last_status.update!(last_status_id: latest_status_id)
      else
        HashtagLastStatus.create!(
          hashtag_name: hashtag,
          last_status_id: latest_status_id
        )
      end
      logger.info "Updated last status ID for hashtag #{hashtag}: #{latest_status_id}"
    end

  rescue => e
    logger.error "Error processing hashtag #{hashtag}: #{e.message}"
  end
end
