# frozen_string_literal: true

class AddRejectInvalidSubscriptionToDomainBlocks < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      remove_column :domain_blocks, :reject_send_unlisted_dissubscribable

      change_table :domain_blocks do |t|
        t.boolean :detect_invalid_subscription, null: false, default: false
      end
    end
  end

  def down
    safety_assured do
      remove_column :domain_blocks, :detect_invalid_subscription

      change_table :domain_blocks do |t|
        t.boolean :reject_send_unlisted_dissubscribable, null: false, default: false
      end
    end
  end
end
