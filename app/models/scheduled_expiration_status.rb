# frozen_string_literal: true

# == Schema Information
#
# Table name: scheduled_expiration_statuses
#
#  id           :bigint(8)        not null, primary key
#  scheduled_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint(8)
#  status_id    :bigint(8)        not null
#

class ScheduledExpirationStatus < ApplicationRecord
  include Paginable

  TOTAL_LIMIT = 300
  DAILY_LIMIT = 25

  belongs_to :account, inverse_of: :scheduled_expiration_statuses
  belongs_to :status,  inverse_of: :scheduled_expiration_status

  validate :validate_total_limit
  validate :validate_daily_limit

  private

  def validate_total_limit
    errors.add(:base, I18n.t('scheduled_expiration_statuses.over_total_limit', limit: TOTAL_LIMIT)) if account.scheduled_expiration_statuses.count >= TOTAL_LIMIT
  end

  def validate_daily_limit
    errors.add(:base, I18n.t('scheduled_expiration_statuses.over_daily_limit', limit: DAILY_LIMIT)) if account.scheduled_expiration_statuses.where('scheduled_at::date = ?::date', scheduled_at).count >= DAILY_LIMIT
  end
end
