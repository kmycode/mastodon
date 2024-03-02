# frozen_string_literal: true

class ImproveRemotePendingAccountsIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :accounts, :remote_pending, unique: false, algorithm: :concurrently

    add_index :accounts, :id, name: 'index_remote_pending_users', unique: false, algorithm: :concurrently, where: 'domain IS NOT NULL AND remote_pending AND suspended_at IS NOT NULL'
  end
end
