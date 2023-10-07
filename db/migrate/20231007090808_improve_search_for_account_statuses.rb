# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class ImproveSearchForAccountStatuses < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :statuses, [:account_id, :reblog_of_id, :deleted_at, :searchability], name: 'index_statuses_for_get_following_accounts_to_search', where: 'deleted_at IS NULL AND reblog_of_id IS NULL AND searchability IN (0, 10, 1)'
    end
  end
end
