# frozen_string_literal: true

# == Schema Information
#
# Table name: status_references
#
#  id               :bigint(8)        not null, primary key
#  status_id        :bigint(8)        not null
#  target_status_id :bigint(8)        not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  attribute_type   :string
#  quote            :boolean          default(FALSE), not null
#

class StatusReference < ApplicationRecord
  belongs_to :status
  belongs_to :target_status, class_name: 'Status'

  has_one :notification, as: :activity, dependent: :destroy

  after_commit :reset_parent_cache
  after_create_commit :set_quote
  after_destroy_commit :remove_quote

  private

  def reset_parent_cache
    Rails.cache.delete("statuses/#{status_id}")
    Rails.cache.delete("statuses/#{target_status_id}")
  end

  def set_quote
    return unless quote
    return if status.quote_of_id.present?

    status.quote_of_id = target_status_id
  end

  def remove_quote
    return unless quote
    return unless status.quote_of_id == target_status_id

    status.quote_of_id = nil
  end
end
