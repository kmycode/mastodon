# frozen_string_literal: true

class UserSettings
  class Error < StandardError; end
  class KeyError < Error; end

  include UserSettings::DSL
  include UserSettings::Glue

  setting :always_send_emails, default: false
  setting :aggregate_reblogs, default: true
  setting :theme, default: -> { ::Setting.theme }
  setting :noindex, default: -> { ::Setting.noindex }
  setting :noai, default: true
  setting :bio_markdown, default: false
  setting :hide_statuses_count, default: false
  setting :hide_following_count, default: false
  setting :hide_followers_count, default: false
  setting :show_application, default: true
  setting :default_language, default: nil
  setting :default_sensitive, default: false
  setting :default_privacy, default: nil, in: %w(public public_unlisted login unlisted private)
  setting :default_reblog_privacy, default: nil
  setting :default_searchability, default: :direct, in: %w(public private direct limited)
  setting :disallow_unlisted_public_searchability, default: false
  setting :public_post_to_unlisted, default: false
  setting :reject_public_unlisted_subscription, default: false
  setting :reject_unlisted_subscription, default: false
  setting :send_without_domain_blocks, default: false
  setting :reaction_deck, default: nil
  setting :stop_emoji_reaction_streaming, default: false
  setting :emoji_reaction_streaming_notify_impl2, default: false

  namespace :web do
    setting :advanced_layout, default: false
    setting :trends, default: true
    setting :use_blurhash, default: true
    setting :use_pending_items, default: false
    setting :use_system_font, default: false
    setting :disable_swiping, default: false
    setting :delete_modal, default: true
    setting :enable_login_privacy, default: false
    setting :hide_recent_emojis, default: false
    setting :reblog_modal, default: false
    setting :unfollow_modal, default: true
    setting :reduce_motion, default: false
    setting :expand_content_warnings, default: false
    setting :display_media, default: 'default', in: %w(default show_all hide_all)
    setting :display_media_expand, default: true
    setting :auto_play, default: true
  end

  namespace :notification_emails do
    setting :follow, default: true
    setting :reblog, default: false
    setting :favourite, default: false
    setting :mention, default: true
    setting :follow_request, default: true
    setting :report, default: true
    setting :pending_account, default: true
    setting :trends, default: true
    setting :appeal, default: true
    setting :warning, default: true
  end

  namespace :interactions do
    setting :must_be_follower, default: false
    setting :must_be_following, default: false
    setting :must_be_following_dm, default: false
  end

  namespace :emoji_reactions do
    setting :must_be_follower, default: false
    setting :must_be_following, default: false
    setting :deny_from_all, default: false
  end

  def initialize(original_hash)
    @original_hash = original_hash || {}
  end

  def [](key)
    key = key.to_sym

    raise KeyError, "Undefined setting: #{key}" unless self.class.definition_for?(key)

    if @original_hash.key?(key)
      @original_hash[key]
    else
      self.class.definition_for(key).default_value
    end
  end

  def []=(key, value)
    key = key.to_sym

    raise KeyError, "Undefined setting: #{key}" unless self.class.definition_for?(key)

    setting_definition = self.class.definition_for(key)
    typecast_value = setting_definition.type_cast(value)

    raise ArgumentError, "Invalid value for setting #{key}: #{typecast_value}" if setting_definition.in.present? && setting_definition.in.exclude?(typecast_value)

    if typecast_value.nil?
      @original_hash.delete(key)
    else
      @original_hash[key] = typecast_value
    end
  end

  def update(params)
    params.each do |k, v|
      self[k] = v unless v.nil?
    end
  end

  keys.each do |key|
    define_method(key) do
      self[key]
    end
  end

  def as_json
    @original_hash
  end
end
