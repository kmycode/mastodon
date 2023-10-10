# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddDeliveryLocalToFriendDomains < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      add_column_with_default :friend_domains, :delivery_local, :boolean, default: true, allow_null: false
    end
  end
end
