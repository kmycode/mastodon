# frozen_string_literal: true

require 'singleton'
require 'yaml'

class ChewyConfig
  include Singleton

  class InvalidElasticSearchVersionError < Mastodon::Error; end

  CONFIG_VERSION = 1

  def initialize
    custom_config_file = Rails.root.join('.elasticsearch.yml')
    default_config_file = Rails.root.join('config', 'elasticsearch.default.yml')

    custom_config = nil
    custom_config = YAML.load_file(custom_config_file) if File.exist?(custom_config_file)
    default_config = YAML.load_file(default_config_file)

    @config = default_config.merge(custom_config || {})
    @config = @config.merge(YAML.load_file(Rails.root.join('config', 'elasticsearch.default-ja-sudachi.yml'))) if Rails.env.test?

    raise InvalidElasticSearchVersionError, "ElasticSearch config version is missmatch. expected version=#{CONFIG_VERSION} actual version=#{@config['version']}" if @config['version'] != CONFIG_VERSION
  end

  attr_reader :config

  def accounts
    config['accounts']
  end

  def accounts_analyzers
    config['accounts_analyzers']
  end

  def public_statuses
    config['public_statuses']
  end

  def public_statuses_analyzers
    config['public_statuses_analyzers']
  end

  def statuses
    config['statuses']
  end

  def statuses_analyzers
    config['statuses_analyzers']
  end

  def tags
    config['tags']
  end

  def tags_analyzers
    config['tags_analyzers']
  end
end
