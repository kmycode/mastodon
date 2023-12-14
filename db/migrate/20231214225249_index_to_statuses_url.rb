# frozen_string_literal: true

class IndexToStatusesURL < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    add_index :statuses, :url, name: :index_statuses_on_url, algorithm: :concurrently, opclass: :text_pattern_ops, where: 'url IS NOT NULL AND url <> uri'
  end

  def down
    remove_index :statuses, name: :index_statuses_on_url
  end
end
