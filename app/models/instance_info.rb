# frozen_string_literal: true

# == Schema Information
#
# Table name: instance_infos
#
#  id         :bigint(8)        not null, primary key
#  domain     :string           default(""), not null
#  software   :string           default(""), not null
#  version    :string           default(""), not null
#  data       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class InstanceInfo < ApplicationRecord
  EMOJI_REACTION_AVAILABLE_SOFTWARES = %w(
    misskey
    calckey
    cherrypick
    meisskey
    firefish
    renedon
    fedibird
    kmyblue
    pleroma
    akkoma
  ).freeze

  def self.emoji_reaction_available?(domain)
    return Setting.enable_emoji_reaction if domain.nil?

    Rails.cache.fetch("emoji_reaction_available_domain:#{domain}") { fetch_emoji_reaction_available(domain) }
  end

  def self.fetch_emoji_reaction_available(domain)
    return Setting.enable_emoji_reaction if domain.nil?

    info = InstanceInfo.find_by(domain: domain)
    return false if info.nil?

    return true if EMOJI_REACTION_AVAILABLE_SOFTWARES.include?(info['software'])

    features = info.data.dig('metadata', 'features')
    return false if features.nil? || !features.is_a?(Array)

    features.include?('emoji_reaction')
  end
end
