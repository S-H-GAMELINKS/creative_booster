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
end

hashtags.each do |hashtag|
  begin
    # このハッシュタグの最後に処理したステータスIDを取得
    last_status = HashtagLastStatus.find_by(hashtag_name: hashtag)
    since_id = last_status&.last_status_id

    # since_idを使用して新しい投稿のみを取得
    options = { limit: 100 }
    options[:since_id] = since_id if since_id

    statuses = client.hashtag_timeline(hashtag, options)

    if statuses.size == 0
      logger.info "No new statuses for hashtag: #{hashtag}"
      next
    end

    new_hashtags = []
    latest_status_id = nil

    statuses.each do |status|
      # 最新のステータスIDを記録（最初の要素が最新）
      latest_status_id ||= status.id
      # 既にリブログ済みかチェック
      if RebloggedStatus.exists?(status_id: status.id)
        logger.info "Status #{status.id} already reblogged, skipping"
        next
      end

      # ブーストとお気に入り
      client.reblog(status.id)
      client.favourite(status.id)

      # リブログ履歴を保存
      status_hashtags = status.tags ? status.tags.map(&:name).map(&:downcase) : []
      RebloggedStatus.create!(
        status_id: status.id,
        hashtags: status_hashtags
      )

      # ハッシュタグを収集
      new_hashtags.concat(status_hashtags) if status_hashtags.any?

      logger.info "Reblogged status #{status.id} with hashtags: #{status_hashtags.join(', ')}"
    end

    # 一括でハッシュタグを処理
    if new_hashtags.any?
      unique_hashtags = new_hashtags.uniq
      existing_hashtags = Hashtag.where(name: unique_hashtags).pluck(:name)
      hashtags_to_create = unique_hashtags - existing_hashtags

      hashtags_to_create.each do |tag_name|
        Hashtag.create!(name: tag_name)
        logger.info "New hashtag learned: #{tag_name}"
      end
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
