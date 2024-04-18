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
    rosekey
    sharkey
    tanukey
  ).freeze

  QUOTE_AVAILABLE_SOFTWARES = EMOJI_REACTION_AVAILABLE_SOFTWARES

  STATUS_REFERENCE_AVAILABLE_SOFTWARES = %w(fedibird).freeze

  CIRCLE_AVAILABLE_SOFTWARES = %w(fedibird).freeze

  class << self
    def emoji_reaction_available?(domain)
      return Setting.enable_emoji_reaction if domain.nil?

      Rails.cache.fetch("emoji_reaction_available_domain:#{domain}") { load_emoji_reaction_available(domain) }
    end

    def available_features(domain)
      return local_features if domain.nil?

      Rails.cache.fetch("domain_available_features:#{domain}") { load_available_features(domain) }
    end

    private

    def load_available_features(domain)
      return local_features if domain.nil?

      info = InstanceInfo.find_by(domain: domain)

      {
        emoji_reaction: feature_available?(info, EMOJI_REACTION_AVAILABLE_SOFTWARES, 'emoji_reaction'),
        quote: feature_available?(info, QUOTE_AVAILABLE_SOFTWARES, 'quote'),
        status_reference: feature_available?(info, STATUS_REFERENCE_AVAILABLE_SOFTWARES, 'status_reference'),
        circle: feature_available?(info, CIRCLE_AVAILABLE_SOFTWARES, 'circle'),
      }
    end

    def local_features
      {
        emoji_reaction: Setting.enable_emoji_reaction,
        quote: true,
        status_reference: true,
        circle: true,
      }
    end

    def feature_available?(info, softwares, feature_name)
      return false if info.nil?

      softwares.include?(software_name(info)) || metadata_features(info)&.include?(feature_name) || false
    end

    def metadata_features(info)
      return nil unless info.data.is_a?(Hash) && info.data['metadata'].is_a?(Hash) && info.data['metadata']['features'].is_a?(Array)

      info.data['metadata']['features']
    end

    def software_name(info)
      info.software
    end
  end

  private

  def reset_cache
    Rails.cache.delete("emoji_reaction_available_domain:#{domain}")
    Rails.cache.delete("domain_available_features:#{domain}")
  end
end
