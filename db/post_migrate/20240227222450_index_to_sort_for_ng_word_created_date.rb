# frozen_string_literal: true

class IndexToSortForNgWordCreatedDate < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :ngword_histories, :created_at, algorithm: :concurrently
  end
end
