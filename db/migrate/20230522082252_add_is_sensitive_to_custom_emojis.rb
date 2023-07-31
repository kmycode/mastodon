# frozen_string_literal: true

class AddIsSensitiveToCustomEmojis < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :custom_emojis do |t|
        t.boolean :is_sensitive, null: false, default: false
      end
    end
  end
end
