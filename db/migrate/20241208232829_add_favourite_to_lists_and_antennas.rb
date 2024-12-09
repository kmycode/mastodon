# frozen_string_literal: true

class AddFavouriteToListsAndAntennas < ActiveRecord::Migration[7.2]
  class Antenna < ApplicationRecord; end

  def up
    add_column :lists, :favourite, :boolean, null: false, default: true
    add_column :antennas, :favourite, :boolean, null: false, default: true

    Antenna.where(insert_feeds: true).in_batches.update_all(favourite: false)
  end

  def down
    remove_column :lists, :favourite
    remove_column :antennas, :favourite
  end
end
