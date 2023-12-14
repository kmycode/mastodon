# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddQuoteToStatuses < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class StatusReference < ApplicationRecord
    belongs_to :status
    belongs_to :target_status, class_name: 'Status'
  end

  def up
    safety_assured do
      add_column_with_default :statuses, :quote_of_id, :bigint, default: nil, allow_null: true

      StatusReference.transaction do
        StatusReference.where(quote: true).includes(:status).find_each do |ref|
          ref.status.update(quote_of_id: ref.target_status_id)
        end
      end
    end
  end

  def down
    safety_assured do
      remove_column :statuses, :quote_of_id
    end
  end
end
