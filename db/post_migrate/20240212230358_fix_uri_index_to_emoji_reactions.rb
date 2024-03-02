# frozen_string_literal: true

class FixUriIndexToEmojiReactions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  class EmojiReaction < ApplicationRecord
  end

  def up
    # Remove duplications (very old kmyblue code [2023/03-04] maybe made some duplications)
    duplications = EmojiReaction.where('uri IN (SELECT uri FROM emoji_reactions GROUP BY uri HAVING COUNT(*) > 1)')
                                .to_a.group_by(&:uri).to_h

    if duplications.any?
      EmojiReaction.transaction do
        duplications.each do |h|
          h[1].drop(1).each(&:destroy)
        end
      end
    end

    add_index :emoji_reactions, :uri, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :emoji_reactions, :uri
  end
end
