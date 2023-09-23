# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class CreateCircleStatuses < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  def change
    safety_assured do
      create_table :circle_statuses do |t|
        t.belongs_to :circle, null: true, foreign_key: { on_delete: :cascade }
        t.belongs_to :status, null: false, foreign_key: { on_delete: :cascade }
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false
      end

      add_index :circle_statuses, [:circle_id, :status_id], unique: true
    end
  end
end
