require 'active_record'
require 'sqlite3'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'hashtags.db'
)

unless ActiveRecord::Base.connection.table_exists?(:hashtags)
  ActiveRecord::Schema.define do
    create_table :hashtags do |t|
      t.string :name, null: false
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :hashtags, :name, unique: true
    add_index :hashtags, :active
  end
end

unless ActiveRecord::Base.connection.table_exists?(:reblogged_statuses)
  ActiveRecord::Schema.define do
    create_table :reblogged_statuses do |t|
      t.string :status_id, null: false
      t.text :hashtags
      t.timestamps
    end
    
    add_index :reblogged_statuses, :status_id, unique: true
    add_index :reblogged_statuses, :created_at
  end
end

unless ActiveRecord::Base.connection.table_exists?(:hashtag_last_statuses)
  ActiveRecord::Schema.define do
    create_table :hashtag_last_statuses do |t|
      t.string :hashtag_name, null: false
      t.string :last_status_id, null: false
      t.timestamps
    end
    
    add_index :hashtag_last_statuses, :hashtag_name, unique: true
  end
end

class Hashtag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end

class RebloggedStatus < ActiveRecord::Base
  validates :status_id, presence: true, uniqueness: true
  
  serialize :hashtags, Array
end

class HashtagLastStatus < ActiveRecord::Base
  validates :hashtag_name, presence: true, uniqueness: true
  validates :last_status_id, presence: true
end
