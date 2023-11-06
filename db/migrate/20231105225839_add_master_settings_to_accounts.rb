# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddMasterSettingsToAccounts < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class Account < ApplicationRecord; end

  def up
    safety_assured do
      add_column :accounts, :master_settings, :jsonb

      Account.transaction do
        Account.find_in_batches do |accounts|
          accounts.each do |account|
            account.update(master_settings: { 'subscribtion_policy' => account.dissubscribable ? 'block' : 'allow' })
          end
        end
      end

      remove_column :accounts, :dissubscribable
    end
  end

  def down
    safety_assured do
      add_column_with_default :accounts, :dissubscribable, :boolean, default: false, allow_null: false

      Account.transaction do
        Account.find_in_batches do |accounts|
          accounts.each do |account|
            account.update(dissubscribable: account.master_settings.present? && account.master_settings['subscribtion_policy'] != 'allow')
          end
        end
      end

      remove_column :accounts, :master_settings
    end
  end
end
