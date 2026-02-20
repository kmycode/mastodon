# frozen_string_literal: true

# == Schema Information
#
# Table name: antenna_accounts
#
#  id         :bigint(8)        not null, primary key
#  exclude    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#  antenna_id :bigint(8)        not null
#
class AntennaAccount < ApplicationRecord
  belongs_to :antenna
  belongs_to :account

  validate :limit_per_antenna

  validates :account_id, uniqueness: { scope: :antenna_id }

  private

  def limit_per_antenna
    raise Mastodon::ValidationError, I18n.t('antennas.errors.limit.accounts') if AntennaAccount.where(antenna_id: antenna_id).count >= Antenna::ACCOUNTS_PER_ANTENNA_LIMIT
  end
end
