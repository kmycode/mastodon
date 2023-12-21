# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class RemoveRemoteUriFromLocalCustomEmojis < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class CustomEmoji < ApplicationRecord; end

  def up
    safety_assured do
      CustomEmoji.transaction do
        CustomEmoji.where(domain: nil).update_all(image_remote_url: nil, uri: nil)
      end
    end
  end

  def down; end
end
