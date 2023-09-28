# frozen_string_literal: true

module Mastodon
  module Version
    module_function

    def kmyblue_major
      6
    end

    def kmyblue_minor
      0
    end

    def kmyblue_flag
      nil # 'LTS'
    end

    def major
      4
    end

    def minor
      2
    end

    def patch
      0
    end

    def default_prerelease
      ''
    end

    def prerelease
      ENV['MASTODON_VERSION_PRERELEASE'].presence || default_prerelease
    end

    def to_a_of_kmyblue
      [kmyblue_major, kmyblue_minor].compact
    end

    def to_s_of_kmyblue
      components = [to_a_of_kmyblue.join('.')]
      components << "-#{kmyblue_flag}" if kmyblue_flag.present?
      components.join
    end

    def build_metadata
      ['kmyblue', to_s_of_kmyblue, ENV.fetch('MASTODON_VERSION_METADATA', nil)].compact.join('.')
    end

    def to_a
      [major, minor, patch].compact
    end

    def to_s
      components = [to_a.join('.')]
      components << "-#{prerelease}" if prerelease.present?
      components << "+#{build_metadata}" if build_metadata.present?
      components.join
    end

    def gem_version
      @gem_version ||= if ENV.fetch('UPDATE_CHECK_SOURCE', 'kmyblue') == 'kmyblue'
                         Gem::Version.new("#{kmyblue_major}.#{kmyblue_minor}")
                       else
                         Gem::Version.new(to_s.split('+')[0])
                       end
    end

    def repository
      ENV.fetch('GITHUB_REPOSITORY', 'kmycode/mastodon')
    end

    def source_base_url
      ENV.fetch('SOURCE_BASE_URL', "https://github.com/#{repository}")
    end

    # specify git tag or commit hash here
    def source_tag
      ENV.fetch('SOURCE_TAG', nil)
    end

    def source_url
      if source_tag
        "#{source_base_url}/tree/#{source_tag}"
      else
        source_base_url
      end
    end

    def user_agent
      @user_agent ||= "#{HTTP::Request::USER_AGENT} (Mastodon/#{Version}; +http#{Rails.configuration.x.use_https ? 's' : ''}://#{Rails.configuration.x.web_domain}/)"
    end
  end
end
