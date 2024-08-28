# frozen_string_literal: true

class CreateCustomCsses < ActiveRecord::Migration[7.1]
  def change
    create_table :custom_csses do |t|
      t.belongs_to :user, foreign_key: { on_delete: :cascade }, null: false
      t.string :css, null: false, default: ''

      t.timestamps
    end
  end
end
