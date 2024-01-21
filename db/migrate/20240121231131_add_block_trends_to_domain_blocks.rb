# frozen_string_literal: true

class AddBlockTrendsToDomainBlocks < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :domain_blocks, :block_trends, :boolean, default: false, null: false
  end
end
