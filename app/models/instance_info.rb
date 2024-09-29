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
    tanukey
  ).freeze

  QUOTE_AVAILABLE_SOFTWARES = EMOJI_REACTION_AVAILABLE_SOFTWARES + %w(bridgy-fed).freeze

  STATUS_REFERENCE_AVAILABLE_SOFTWARES = %w(fedibird).freeze

  CIRCLE_AVAILABLE_SOFTWARES = %w(fedibird).freeze

  MISSKEY_FORKS = %w(
    calckey
    cherrypick
    firefish
    iceshrimp
    meisskey
    misskey
    rosekey
    sharkey
    tanukey
  ).freeze

  INVALID_SUBSCRIPTION_SOFTWARES = MISSKEY_FORKS - %w(firefish)

  PROXY_ACCOUNT_SOFTWARES = MISSKEY_FORKS

  NO_LANGUAGE_FLAG_SOFTWARES = MISSKEY_FORKS - %w(firefish)

  class << self
    def available_features(domain)
      return local_features if domain.nil?

      Rails.cache.fetch("domain_available_features:#{domain}") { load_available_features(domain) }
    end

    def invalid_subscription_software?(domain)
      INVALID_SUBSCRIPTION_SOFTWARES.include?(software_name(domain))
    end

    def proxy_account_software?(domain)
      PROXY_ACCOUNT_SOFTWARES.include?(software_name(domain))
    end

    def no_language_flag_software?(domain)
      NO_LANGUAGE_FLAG_SOFTWARES.include?(software_name(domain))
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

      softwares.include?(info.software) || metadata_features(info)&.include?(feature_name) || false
    end

    def metadata_features(info)
      return nil unless info.data.is_a?(Hash) && info.data['metadata'].is_a?(Hash) && info.data['metadata']['features'].is_a?(Array)

      info.data['metadata']['features']
    end

    def software_name(domain)
      Rails.cache.fetch("software_name:#{domain}") { load_software_name(domain) }
    end

    def load_software_name(domain)
      return 'threads' if domain == 'threads.net'

      info = InstanceInfo.find_by(domain: domain)
      return nil if info.nil?

      info.software
    end
  end

  private

  def reset_cache
    Rails.cache.delete("domain_available_features:#{domain}")
    Rails.cache.delete("software_name:#{domain}")
  end
end
