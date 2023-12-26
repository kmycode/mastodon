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
  setting :translatable_private, default: false
  setting :link_preview, default: true
  setting :bio_markdown, default: false
  setting :discoverable_local, default: false
  setting :hide_statuses_count, default: false
  setting :hide_following_count, default: false
  setting :hide_followers_count, default: false
  setting :show_application, default: true
  setting :default_language, default: nil
  setting :default_sensitive, default: false
  setting :default_privacy, default: nil, in: %w(public public_unlisted login unlisted private)
  setting :stay_privacy, default: false
  setting :default_reblog_privacy, default: nil
  setting :default_searchability, default: :direct, in: %w(public private direct limited public_unlisted)
  setting :default_searchability_of_search, default: :public, in: %w(public private direct limited)
  setting :use_public_index, default: true
  setting :disallow_unlisted_public_searchability, default: false
  setting :public_post_to_unlisted, default: false
  setting :reject_public_unlisted_subscription, default: false
  setting :reject_unlisted_subscription, default: false
  setting :send_without_domain_blocks, default: false
  setting :reaction_deck, default: nil
  setting :stop_emoji_reaction_streaming, default: false
  setting :emoji_reaction_streaming_notify_impl2, default: false
  setting :emoji_reaction_policy, default: :allow, in: %w(allow outside_only followers_only following_only mutuals_only block)
  setting :slip_local_emoji_reaction, default: false
  setting :dtl_force_visibility, default: :unchange, in: %w(unchange public public_unlisted unlisted)
  setting :dtl_force_searchability, default: :unchange, in: %w(unchange public public_unlisted)
  setting :dtl_force_subscribable, default: false
  setting :lock_follow_from_bot, default: false
  setting :allow_quote, default: true

  setting_inverse_alias :indexable, :noindex

  namespace :web do
    setting :advanced_layout, default: false
    setting :trends, default: true
    setting :use_blurhash, default: true
    setting :use_pending_items, default: false
    setting :use_system_font, default: false
    setting :bookmark_category_needed, default: false
    setting :disable_swiping, default: false
    setting :delete_modal, default: true
    setting :enable_login_privacy, default: false
    setting :enable_dtl_menu, default: false
    setting :hide_recent_emojis, default: false
    setting :enable_emoji_reaction, default: true
    setting :show_emoji_reaction_on_timeline, default: true
    setting :reblog_modal, default: false
    setting :unfollow_modal, default: true
    setting :reduce_motion, default: false
    setting :expand_content_warnings, default: false
    setting :display_media, default: 'default', in: %w(default show_all hide_all)
    setting :display_media_expand, default: true
    setting :auto_play, default: true
    setting :simple_timeline_menu, default: false
    setting :show_quote_in_home, default: true
    setting :show_quote_in_public, default: false
    setting :hide_blocking_quote, default: true
    setting :hide_emoji_reaction_unavailable_server, default: false
    setting :hide_favourite_menu, default: false
  end

  namespace :notification_emails do
    setting :follow, default: true
    setting :reblog, default: false
    setting :favourite, default: false
    setting :mention, default: true
    setting :follow_request, default: true
    setting :report, default: true
    setting :pending_account, default: true
    setting :pending_friend_server, default: true
    setting :trends, default: true
    setting :appeal, default: true
    setting :software_updates, default: 'critical', in: %w(none critical patch all)
  end

  namespace :interactions do
    setting :must_be_follower, default: false
    setting :must_be_following, default: false
    setting :must_be_following_dm, default: false
  end

  def initialize(original_hash)
    @original_hash = original_hash || {}
  end

  def [](key)
    definition = self.class.definition_for(key)

    raise KeyError, "Undefined setting: #{key}" if definition.nil?

    definition.value_for(key, @original_hash[definition.key])
  end

  def []=(key, value)
    definition = self.class.definition_for(key)

    raise KeyError, "Undefined setting: #{key}" if definition.nil?

    typecast_value = definition.type_cast(value)

    raise ArgumentError, "Invalid value for setting #{definition.key}: #{typecast_value}" if definition.in.present? && definition.in.exclude?(typecast_value)

    if typecast_value.nil?
      @original_hash.delete(definition.key)
    else
      @original_hash[definition.key] = definition.value_for(key, typecast_value)
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
