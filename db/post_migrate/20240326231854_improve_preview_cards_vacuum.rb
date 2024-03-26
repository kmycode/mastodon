# frozen_string_literal: true

class ImprovePreviewCardsVacuum < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :preview_cards, :id, name: 'index_preview_cards_vacuum', where: "image_file_name IS NOT NULL AND image_file_name <> ''", algorithm: :concurrently
    add_index :media_attachments, :id, name: 'index_media_attachments_vacuum', where: "file_file_name IS NOT NULL AND remote_url <> ''", algorithm: :concurrently
  end
end
