# frozen_string_literal: true

class AddMarkdownToStatusEdits < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :status_edits, :markdown, :boolean, default: false
    end
  end
end
