# frozen_string_literal: true

class AddMarkdownToStatuses < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :statuses, :markdown, :boolean, default: false
    end
  end
end
