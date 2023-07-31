# frozen_string_literal: true

class AddRejectSendingToDomainBlocks < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :domain_blocks, bulk: true do |t|
        t.boolean :reject_send_not_public_searchability, null: false, default: false
        t.boolean :reject_send_unlisted_dissubscribable, null: false, default: false
        t.boolean :reject_send_public_unlisted, null: false, default: false
        t.boolean :reject_send_dissubscribable, null: false, default: false
        t.boolean :reject_send_media, null: false, default: false
        t.boolean :reject_send_sensitive, null: false, default: false
      end
    end
  end

  def down
    safety_assured do
      change_table :domain_blocks, bulk: true do |t|
        t.remove :reject_send_not_public_searchability
        t.remove :reject_send_unlisted_dissubscribable
        t.remove :reject_send_public_unlisted
        t.remove :reject_send_dissubscribable
        t.remove :reject_send_media
        t.remove :reject_send_sensitive
      end
    end
  end
end
