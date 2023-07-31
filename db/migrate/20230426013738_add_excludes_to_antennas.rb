# frozen_string_literal: true

class AddExcludesToAntennas < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      change_table :antennas, bulk: true do |t|
        t.jsonb :exclude_domains
        t.jsonb :exclude_accounts
        t.jsonb :exclude_tags
      end
    end
  end

  def down
    safety_assured do
      change_table :antennas, bulk: true do |t|
        t.remove :exclude_domains
        t.remove :exclude_accounts
        t.remove :exclude_tags
      end
    end
  end
end
