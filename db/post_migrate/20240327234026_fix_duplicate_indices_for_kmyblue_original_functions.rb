# frozen_string_literal: true

class FixDuplicateIndicesForKmyblueOriginalFunctions < ActiveRecord::Migration[7.1]
  def change
    remove_index :antenna_accounts, :antenna_id
    remove_index :antenna_domains, :antenna_id
    remove_index :antenna_tags, :antenna_id
    remove_index :bookmark_category_statuses, :bookmark_category_id
    remove_index :circle_accounts, :circle_id
    remove_index :circle_statuses, :circle_id
    remove_index :list_statuses, :list_id
  end
end
