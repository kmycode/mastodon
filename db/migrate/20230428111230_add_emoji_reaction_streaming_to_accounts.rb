# frozen_string_literal: true

class AddEmojiReactionStreamingToAccounts < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :accounts, :stop_emoji_reaction_streaming, :boolean, default: false
    end
  end
end
