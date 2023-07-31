# frozen_string_literal: true

class AddRejectReplyExcludeFollowersToDomainBlocks < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :domain_blocks do |t|
        t.boolean :reject_reply_exclude_followers, null: false, default: false
      end
    end
  end
end
