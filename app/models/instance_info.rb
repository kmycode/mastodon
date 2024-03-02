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
  after_commit :reset_cache

  EMOJI_REACTION_AVAILABLE_SOFTWARES = %w(
    akkoma
    calckey
    catodon
    cherrypick
    fedibird
    firefish
    iceshrimp
    meisskey
    misskey
    pleroma
    sharkey
  ).freeze

  class << self
    def emoji_reaction_available?(domain)
      return Setting.enable_emoji_reaction if domain.nil?

      Rails.cache.fetch("emoji_reaction_available_domain:#{domain}") { load_emoji_reaction_available(domain) }
    end

    private

    def load_emoji_reaction_available(domain)
      info = InstanceInfo.find_by(domain: domain)
      return false if info.nil?
      return true if EMOJI_REACTION_AVAILABLE_SOFTWARES.include?(info['software'])

      return false unless info.data.is_a?(Hash)
      return false unless info.data['metadata'].is_a?(Hash)

      features = info.data.dig('metadata', 'features')
      return false unless features.is_a?(Array)

      features.include?('emoji_reaction')
    end
  end

  private

  def reset_cache
    Rails.cache.delete("emoji_reaction_available_domain:#{domain}")
  end
end
