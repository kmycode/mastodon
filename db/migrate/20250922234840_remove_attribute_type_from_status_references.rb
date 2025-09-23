# frozen_string_literal: true

class RemoveAttributeTypeFromStatusReferences < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :status_references, :attribute_type, :string
    end
  end
end
