# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddMasterSettingsToAccounts < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class Account < ApplicationRecord; end

  def up
    safety_assured do
      add_column :accounts, :master_settings, :jsonb

      ActiveRecord::Base.connection.execute("UPDATE accounts SET master_settings = { subscription_policy: 'block' } WHERE accounts.dissubscribable IS TRUE")
      ActiveRecord::Base.connection.execute("UPDATE accounts SET master_settings = { subscription_policy: 'allow' } WHERE accounts.dissubscribable IS FALSE")

      remove_column :accounts, :dissubscribable
    end
  end

  def down
    safety_assured do
      add_column_with_default :accounts, :dissubscribable, :boolean, default: false, allow_null: false

      ActiveRecord::Base.connection.execute("UPDATE accounts SET dissubscribable = TRUE WHERE master_settings ->> 'subscription_policy' = 'block'")
      ActiveRecord::Base.connection.execute("UPDATE accounts SET dissubscribable = FALSE WHERE master_settings ->> 'subscription_policy' = 'allow'")

      remove_column :accounts, :master_settings
    end
  end
end
