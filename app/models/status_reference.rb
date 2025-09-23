# frozen_string_literal: true

# == Schema Information
#
# Table name: status_references
#
#  id               :bigint(8)        not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  status_id        :bigint(8)        not null
#  target_status_id :bigint(8)        not null
#

class StatusReference < ApplicationRecord
  REFERENCES_LIMIT = 5

  belongs_to :status
  belongs_to :target_status, class_name: 'Status'

  has_one :notification, as: :activity, dependent: :destroy

  after_commit :reset_parent_cache

  private

  def reset_parent_cache
    Rails.cache.delete("statuses/#{status_id}")
    Rails.cache.delete("statuses/#{target_status_id}")
  end
end
