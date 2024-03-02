# frozen_string_literal: true

class AddCountToNgwordHistories < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :ngword_histories, :count, :integer, null: false, default: 0

    add_index :ngword_histories, [:uri, :reason, :created_at], unique: false, algorithm: :concurrently
  end
end
