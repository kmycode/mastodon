# frozen_string_literal: true

# == Schema Information
#
# Table name: antenna_tags
#
#  id         :bigint(8)        not null, primary key
#  exclude    :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  antenna_id :bigint(8)        not null
#  tag_id     :bigint(8)        not null
#
class AntennaTag < ApplicationRecord
  belongs_to :antenna
  belongs_to :tag

  validate :limit_per_antenna

  validates :tag_id, uniqueness: { scope: :antenna_id }

  private

  def limit_per_antenna
    raise Mastodon::ValidationError, I18n.t('antennas.errors.limit.tags') if AntennaTag.where(antenna_id: antenna_id).count >= Antenna::TAGS_PER_ANTENNA_LIMIT
  end
end
