# frozen_string_literal: true

class RemoveUnusedTable < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute('DROP TABLE IF EXISTS account_groups CASCADE')
      execute('ALTER TABLE status_stats DROP COLUMN IF EXISTS test')
    end
  end

  def down; end
end
