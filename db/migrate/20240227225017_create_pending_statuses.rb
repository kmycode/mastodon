# frozen_string_literal: true

class CreatePendingStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :pending_statuses do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :fetch_account, null: false, foreign_key: { to_table: 'accounts', on_delete: :cascade }
      t.string :uri, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
