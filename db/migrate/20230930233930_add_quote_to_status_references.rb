# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddQuoteToStatusReferences < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class StatusReference < ApplicationRecord; end

  def up
    safety_assured do
      add_column_with_default :status_references, :quote, :boolean, default: false, allow_null: false
      StatusReference.where(attribute_type: 'QT').update_all(quote: true)
    end
  end

  def down
    safety_assured do
      remove_column :status_references, :quote
    end
  end
end
