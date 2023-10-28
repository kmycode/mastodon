# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class CreateListStatuses < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      create_table :list_statuses do |t|
        t.belongs_to :list, null: false, foreign_key: { on_delete: :cascade }
        t.belongs_to :status, null: false, foreign_key: { on_delete: :cascade }
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false
      end

      add_index :list_statuses, [:list_id, :status_id], unique: true
    end
  end
end
