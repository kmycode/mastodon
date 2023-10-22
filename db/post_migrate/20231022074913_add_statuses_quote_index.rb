# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddStatusesQuoteIndex < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured { add_index :statuses, [:quote_of_id, :account_id], unique: false }
  end
end
