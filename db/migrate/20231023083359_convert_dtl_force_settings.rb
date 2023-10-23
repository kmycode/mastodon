# frozen_string_literal: true

require Rails.root.join('lib', 'mastodon', 'migration_helpers')

class ConvertDtlForceSettings < ActiveRecord::Migration[7.0]
  include Mastodon::MigrationHelpers

  disable_ddl_transaction!

  class User < ApplicationRecord; end

  def up
    safety_assured do
      User.transaction do
        User.find_in_batches do |users|
          users.filter { |user| user.settings.present? }.each do |user|
            json = Oj.load(user.settings, symbol_keys: true)
            dtl_force_with_tag = json.delete(:dtl_force_with_tag)
            next if dtl_force_with_tag.blank?

            json[:dtl_force_visibility] = dtl_force_with_tag == 'full' ? 'unlisted' : 'unchange'
            json[:dtl_force_searchability] = dtl_force_with_tag == 'none' ? 'unchange' : 'public'
            user.update(settings: Oj.dump(json))
          end
        end
      end
    end
  end

  def down
    safety_assured do
      User.transaction do
        User.find_in_batches do |users|
          users.filter { |user| user.settings.present? }.each do |user|
            json = Oj.load(user.settings, symbol_keys: true)
            dtl_force_visibility = json.delete(:dtl_force_visibility)
            dtl_force_searchability = json.delete(:dtl_force_searchability)
            next unless dtl_force_visibility.present? || dtl_force_searchability.present?

            json[:dtl_force_with_tag] = case dtl_force_visibility
                                        when 'unlisted'
                                          'full'
                                        else
                                          dtl_force_searchability == 'unchange' ? 'none' : 'searchability'
                                        end
            user.update(settings: Oj.dump(json))
          end
        end
      end
    end
  end
end
