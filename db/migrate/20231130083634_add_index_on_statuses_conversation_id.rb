# frozen_string_literal: true

class AddIndexOnStatusesConversationId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :statuses, :conversation_id, algorithm: :concurrently
  end
end
