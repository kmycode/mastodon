# frozen_string_literal: true

class AddWithProfileToCustomFilters < ActiveRecord::Migration[7.1]
  def change
    add_column :custom_filters, :with_profile, :boolean, default: false, null: false
  end
end
