# frozen_string_literal: true

class FixUriIndexToEmojiReactions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :emoji_reactions, :uri, unique: true, algorithm: :concurrently
  end
end
