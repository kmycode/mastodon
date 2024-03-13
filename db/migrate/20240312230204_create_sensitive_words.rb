# frozen_string_literal: true

class CreateSensitiveWords < ActiveRecord::Migration[7.1]
  def change
    create_table :sensitive_words do |t|
      t.string :keyword, null: false
      t.boolean :regexp, null: false, default: false
      t.boolean :remote, null: false, default: false

      t.timestamps
    end
  end
end
