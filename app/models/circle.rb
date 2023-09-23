# frozen_string_literal: true

# == Schema Information
#
# Table name: circles
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)        not null
#  title      :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Circle < ApplicationRecord
  include Paginable

  PER_ACCOUNT_LIMIT = 100

  belongs_to :account

  has_many :circle_accounts, inverse_of: :circle, dependent: :destroy
  has_many :accounts, through: :circle_accounts
  has_many :circle_statuses, inverse_of: :circle, dependent: :destroy
  has_many :statuses, through: :circle_statuses

  validates :title, presence: true

  validates_each :account_id, on: :create do |record, _attr, value|
    record.errors.add(:base, I18n.t('lists.errors.limit')) if List.where(account_id: value).count >= PER_ACCOUNT_LIMIT
  end
end
