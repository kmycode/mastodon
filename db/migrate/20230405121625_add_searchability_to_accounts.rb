# frozen_string_literal: true

class AddSearchabilityToAccounts < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :accounts, :searchability, :integer, null: false, default: 0
    end
  end
end
