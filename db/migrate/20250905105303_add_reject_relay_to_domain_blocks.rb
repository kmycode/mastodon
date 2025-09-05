# frozen_string_literal: true

class AddRejectRelayToDomainBlocks < ActiveRecord::Migration[8.0]
  def change
    add_column :domain_blocks, :reject_relay, :boolean, null: false, default: false
  end
end
