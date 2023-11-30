# frozen_string_literal: true

class AddIndexOnConversationsAncestorStatusId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :conversations, :ancestor_status_id, where: 'ancestor_status_id IS NOT NULL', algorithm: :concurrently
  end
end
