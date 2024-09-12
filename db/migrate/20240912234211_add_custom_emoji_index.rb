# frozen_string_literal: true

class AddCustomEmojiIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  class CustomEmoji < ApplicationRecord
  end

  def up
    duplications = CustomEmoji.where('uri IN (SELECT uri FROM custom_emojis GROUP BY uri HAVING COUNT(*) > 1)')
                              .to_a.group_by(&:uri).to_h

    if duplications.any?
      CustomEmoji.transaction do
        duplications.each do |h|
          h[1].drop(1).each(&:destroy)
        end
      end
    end

    add_index :custom_emojis, :uri, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :custom_emojis, :uri
  end
end
