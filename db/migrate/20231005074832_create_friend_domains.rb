# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class CreateFriendDomains < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    create_table :friend_domains do |t|
      t.string :domain, null: false, default: '', index: { unique: true }
      t.string :inbox_url, null: false, default: '', index: { unique: true }
      t.integer :active_state, null: false, default: 0
      t.integer :passive_state, null: false, default: 0
      t.string :active_follow_activity_id, null: true
      t.string :passive_follow_activity_id, null: true
      t.boolean :available, null: false, default: true
      t.boolean :public_unlisted, null: false, default: true
      t.boolean :pseudo_relay, null: false, default: false
      t.boolean :unlocked, null: false, default: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
