# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class RemoveLegacyDomainBlockColumns < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      remove_column :domain_blocks, :reject_send_not_public_searchability, :boolean, null: false, default: false
      remove_column :domain_blocks, :reject_send_public_unlisted, :boolean, null: false, default: false
      remove_column :domain_blocks, :reject_send_dissubscribable, :boolean, null: false, default: false
      remove_column :domain_blocks, :reject_send_media, :boolean, null: false, default: false
    end
  end
end
