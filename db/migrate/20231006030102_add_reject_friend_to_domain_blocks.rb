# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddRejectFriendToDomainBlocks < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :domain_blocks, :reject_friend, :boolean, default: false, null: false
    end
  end
end
