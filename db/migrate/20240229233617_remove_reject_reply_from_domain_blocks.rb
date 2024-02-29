# frozen_string_literal: true

class RemoveRejectReplyFromDomainBlocks < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    safety_assured { remove_column :domain_blocks, :reject_reply, :boolean, null: false, default: false }
  end
end
