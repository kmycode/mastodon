# frozen_string_literal: true

class AddSomeToDomainBlocks < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :domain_blocks, bulk: true do |t|
        t.boolean :reject_hashtag, null: false, default: false
        t.boolean :reject_straight_follow, null: false, default: false
        t.boolean :reject_new_follow, null: false, default: false
      end
    end
  end

  def down
    safety_assured do
      change_table :domain_blocks, bulk: true do |t|
        t.remove :reject_hashtag
        t.remove :reject_straight_follow
        t.remove :reject_new_follow
      end
    end
  end
end
