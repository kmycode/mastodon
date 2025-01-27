# frozen_string_literal: true

module Mastodon
  module Version
    KMYBLUE_API_VERSION = 2

    module_function

    # If you change the version number, also change the image version in docker-compose.yml.

    def kmyblue_major
      17
    end

    def kmyblue_minor
      0
    end

    def kmyblue_flag
      # 'LTS'
      'dev'
      # nil
    end

    def major
      4
    end

    def minor
      4
    end

    def patch
      0
    end

    def default_prerelease
      'alpha.2'
    end

    def prerelease
      version_configuration[:prerelease].presence || default_prerelease
    end

    def to_a_of_kmyblue
      [kmyblue_major, kmyblue_minor].compact
    end

    def to_s_of_kmyblue
      components = [to_a_of_kmyblue.join('.')]
      components << "-#{kmyblue_flag}" if kmyblue_flag.present?
      components.join
    end

    def to_s_of_mastodon
      components = [to_a.join('.')]
      components << "-#{prerelease}" if prerelease.present?
      components.join
    end

    def build_metadata
      ['kmyblue', to_s_of_kmyblue].compact.join('.')
    end

    def build_metadata_of_mastodon
      version_configuration[:metadata]
    end

    def to_a
      [major, minor, patch].compact
    end

    def to_s
      components = [to_a.join('.')]
      components << "-#{prerelease}" if prerelease.present?
      components << "+#{build_metadata}" if build_metadata.present?
      components << "+#{build_metadata_of_mastodon}" if build_metadata_of_mastodon.present?
      components.join
    end

    def gem_version
      @gem_version ||= if ENV.fetch('UPDATE_CHECK_SOURCE', 'kmyblue') == 'kmyblue'
                         Gem::Version.new("#{kmyblue_major}.#{kmyblue_minor}")
                       else
                         Gem::Version.new(to_s.split('+')[0])
                       end
    end

    def lts?
      kmyblue_flag == 'LTS'
    end

    def dev?
      kmyblue_flag == 'dev'
    end

    def api_versions
      {
        mastodon: 3,
        kmyblue: KMYBLUE_API_VERSION,
      }
    end

    def repository
      source_configuration[:repository]
    end

    def source_base_url
      source_configuration[:base_url] || "https://github.com/#{repository}"
    end

    # specify git tag or commit hash here
    def source_tag
      source_configuration[:tag]
    end

    def source_url
      if source_tag
        "#{source_base_url}/tree/#{source_tag}"
      else
        source_base_url
      end
    end

    def source_commit
      ENV.fetch('SOURCE_COMMIT', nil)
    end

    def user_agent
      @user_agent ||= "Mastodon/#{Version} (#{HTTP::Request::USER_AGENT}; +http#{Rails.configuration.x.use_https ? 's' : ''}://#{Rails.configuration.x.web_domain}/)"
    end

    def version_configuration
      mastodon_configuration.version
    end

    def source_configuration
      mastodon_configuration.source
    end

    def mastodon_configuration
      Rails.configuration.x.mastodon
    end
  end
end
