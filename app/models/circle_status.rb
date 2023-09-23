# frozen_string_literal: true

# == Schema Information
#
# Table name: circle_statuses
#
#  id         :bigint(8)        not null, primary key
#  circle_id  :bigint(8)
#  status_id  :bigint(8)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class CircleStatus < ApplicationRecord
  belongs_to :circle
  belongs_to :status

  validates :status, uniqueness: { scope: :circle }
  validate :account_own_status

  private

  def account_own_status
    errors.add(:status_id, :invalid) unless status.account_id == circle.account_id
  end
end
