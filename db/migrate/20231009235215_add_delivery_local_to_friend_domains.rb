# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddDeliveryLocalToFriendDomains < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def up
    safety_assured do
      add_column_with_default :friend_domains, :delivery_local, :boolean, default: true, allow_null: false
      remove_column :friend_domains, :unlocked
    end
  end

  def down
    safety_assured do
      remove_column :friend_domains, :delivery_local
      add_column_with_default :friend_domains, :unlocked, :boolean, default: false, allow_null: false
    end
  end
end
