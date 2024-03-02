# frozen_string_literal: true

class AddUriToFavourites < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :favourites, :uri, :string
    add_index :favourites, :uri, unique: true, algorithm: :concurrently
  end
end
