# frozen_string_literal: true

class ImproveIndexForPublicTimelineSpeed < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_index :statuses, [:id, :account_id], name: :index_statuses_local_20231213, algorithm: :concurrently, order: { id: :desc }, where: '(local OR (uri IS NULL)) AND deleted_at IS NULL AND visibility IN (0, 10, 11) AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))'
    add_index :statuses, [:id, :account_id], name: :index_statuses_public_20231213, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility IN (0, 10, 11) AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))'
    remove_index :statuses, name: :index_statuses_local_20190824
    remove_index :statuses, name: :index_statuses_public_20200119
  end

  def down
    add_index :statuses, [:id, :account_id], name: :index_statuses_local_20190824, algorithm: :concurrently, order: { id: :desc }, where: '(local OR (uri IS NULL)) AND deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))'
    add_index :statuses, [:id, :account_id], name: :index_statuses_public_20200119, algorithm: :concurrently, order: { id: :desc }, where: 'deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))'
    remove_index :statuses, name: :index_statuses_local_20231213
    remove_index :statuses, name: :index_statuses_public_20231213
  end
end
