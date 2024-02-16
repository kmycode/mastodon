# frozen_string_literal: true

class CreateNgwordHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :ngword_histories do |t|
      t.string :uri, null: false
      t.integer :target_type, null: false
      t.integer :reason, null: false
      t.string :text, null: false
      t.string :keyword, null: false

      t.timestamps
    end

    add_index :ngword_histories, [:uri, :keyword, :created_at], unique: false
  end
end
