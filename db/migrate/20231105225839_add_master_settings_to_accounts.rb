# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddMasterSettingsToAccounts < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class Account < ApplicationRecord; end

  def up
    safety_assured do
      add_column :accounts, :master_settings, :jsonb

      Account.where(dissubscribable: true).update_all(master_settings: "{ subscription_policy: 'block' }") # rubocop:disable Rails/SkipsModelValidations
      Account.where(dissubscribable: false).update_all(master_settings: "{ subscription_policy: 'allow' }") # rubocop:disable Rails/SkipsModelValidations

      remove_column :accounts, :dissubscribable
    end
  end

  def down
    safety_assured do
      add_column_with_default :accounts, :dissubscribable, :boolean, default: false, allow_null: false

      Account.where(master_settings: "{ subscription_policy: 'block' }").update_all(dissubscribable: true) # rubocop:disable Rails/SkipsModelValidations
      Account.where(master_settings: "{ subscription_policy: 'allow' }").update_all(dissubscribable: false) # rubocop:disable Rails/SkipsModelValidations

      remove_column :accounts, :master_settings
    end
  end
end
