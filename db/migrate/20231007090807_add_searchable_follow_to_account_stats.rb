# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddSearchableFollowToAccountStats < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class AccountStat < ApplicationRecord; end

  def change
    safety_assured do
      add_column_with_default :account_stats, :searchable_by_follower, :boolean, default: false, allow_null: false

      AccountStat.where('EXISTS (SELECT 1 FROM statuses WHERE searchability IN (0, 10, 1) AND account_id = account_stats.account_id)')
                 .update_all(searchable_by_follower: true) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
