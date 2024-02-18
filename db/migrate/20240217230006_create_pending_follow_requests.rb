# frozen_string_literal: true

class CreatePendingFollowRequests < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    create_table :pending_follow_requests do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :target_account, null: false, foreign_key: { to_table: 'accounts', on_delete: :cascade }
      t.string :uri, null: false, index: { unique: true }

      t.timestamps
    end

    add_index :pending_follow_requests, [:account_id, :target_account_id], unique: true
  end
end
