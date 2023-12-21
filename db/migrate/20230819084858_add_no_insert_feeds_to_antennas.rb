# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class AddNoInsertFeedsToAntennas < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class Antenna < ApplicationRecord
  end

  def up
    safety_assured do
      add_column_with_default :antennas, :insert_feeds, :boolean, default: false, allow_null: false
      Antenna.where(insert_feeds: false).update_all(insert_feeds: true)
    end
  end

  def down
    remove_column :antennas, :insert_feeds
  end
end
