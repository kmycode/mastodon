# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class RemoveOldAntennaFeeds < ActiveRecord::Migration[7.1]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class Antenna < ApplicationRecord
  end

  def up
    current_id = 1

    Antenna.reorder(:id).select(:id).find_in_batches do |antennas|
      exist_ids = antennas.pluck(:id)
      last_id = exist_ids.max

      ids = Range.new(current_id, last_id).to_a - exist_ids
      FeedManager.instance.clean_feeds!(:antenna, ids)

      current_id = last_id + 1
    end
  end

  def down; end
end
