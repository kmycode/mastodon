# frozen_string_literal: true

# == Schema Information
#
# Table name: circle_accounts
#
#  id         :bigint(8)        not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#  circle_id  :bigint(8)
#  follow_id  :bigint(8)        not null
#

class CircleAccount < ApplicationRecord
  belongs_to :circle
  belongs_to :account
  belongs_to :follow

  validates :account_id, uniqueness: { scope: :circle_id }
  validate :validate_relationship

  before_validation :set_follow

  private

  def set_follow
    return if circle.account_id == account.id

    self.follow = Follow.find_by!(account_id: account.id, target_account_id: circle.account_id)
  end

  def validate_relationship
    return if circle.account_id == account_id

    errors.add(:account_id, 'follow relationship missing') if follow_id.nil?
    errors.add(:follow, 'mismatched accounts') if follow_id.present? && follow.account_id != account_id
  end
end
