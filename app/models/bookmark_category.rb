# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmark_categories
#
#  id         :bigint(8)        not null, primary key
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#

class BookmarkCategory < ApplicationRecord
  include Paginable

  PER_CATEGORY_LIMIT = 20

  belongs_to :account

  has_many :bookmark_category_statuses, inverse_of: :bookmark_category, dependent: :destroy
  has_many :statuses, through: :bookmark_category_statuses

  validates :title, presence: true

  validates_each :account_id, on: :create do |record, _attr, value|
    record.errors.add(:base, I18n.t('bookmark_categories.errors.limit')) if BookmarkCategory.where(account_id: value).count >= PER_CATEGORY_LIMIT
  end
end
