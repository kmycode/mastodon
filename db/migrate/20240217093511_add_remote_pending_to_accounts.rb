# frozen_string_literal: true

class AddRemotePendingToAccounts < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :accounts, :remote_pending, :boolean, null: false, default: false

    add_index :accounts, :remote_pending, unique: false, algorithm: :concurrently
  end
end
