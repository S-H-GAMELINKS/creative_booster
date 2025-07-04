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

class Hashtag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
