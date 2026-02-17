# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmark_category_statuses
#
#  id                   :bigint(8)        not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bookmark_category_id :bigint(8)        not null
#  bookmark_id          :bigint(8)
#  status_id            :bigint(8)        not null
#

class BookmarkCategoryStatus < ApplicationRecord
  include Paginable

  update_index('statuses', :status) if Chewy.enabled?

  belongs_to :bookmark_category
  belongs_to :status
  belongs_to :bookmark

  validates :status_id, uniqueness: { scope: :bookmark_category_id }
  validate :validate_relationship

  before_validation :set_bookmark

  private

  def set_bookmark
    self.bookmark = Bookmark.find_by!(account_id: bookmark_category.account_id, status_id: status_id)
  end

  def validate_relationship
    errors.add(:account_id, 'bookmark relationship missing') if bookmark_id.blank?
  end
end
