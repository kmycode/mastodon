# frozen_string_literal: true

class RemoveGroupAttrsFromAccounts < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :accounts, :group_allow_private_message, :boolean
      remove_column :account_stats, :group_activitypub_count, :integer
    end
  end
end
