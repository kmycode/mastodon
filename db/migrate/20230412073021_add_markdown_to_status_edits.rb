class AddMarkdownToStatusEdits < ActiveRecord::Migration[6.1]
  def change
    add_column :status_edits, :markdown, :boolean, default: false
  end
end