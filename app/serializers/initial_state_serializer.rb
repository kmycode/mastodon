# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  include RoutingHelper
  include DtlHelper

  attributes :meta, :compose, :accounts,
             :media_attachments, :settings,
             :languages

  attribute :critical_updates_pending, if: -> { object&.role&.can?(:view_devops) && SoftwareUpdate.check_enabled? }

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer
  has_one :role, serializer: REST::RoleSerializer

  def meta
    store = {
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      access_token: object.token,
      locale: I18n.locale,
      domain: Addressable::IDNA.to_unicode(instance_presenter.domain),
      title: instance_presenter.title,
      admin: object.admin&.id&.to_s,
      search_enabled: Chewy.enabled?,
      repository: Mastodon::Version.repository,
      source_url: instance_presenter.source_url,
      version: instance_presenter.version,
      limited_federation_mode: Rails.configuration.x.limited_federation_mode,
      mascot: instance_presenter.mascot&.file&.url,
      profile_directory: Setting.profile_directory,
      trends_enabled: Setting.trends,
      registrations_open: Setting.registrations_mode != 'none' && !Rails.configuration.x.single_user_mode,
      timeline_preview: Setting.timeline_preview,
      activity_api_enabled: Setting.activity_api_enabled,
      single_user_mode: Rails.configuration.x.single_user_mode,
      trends_as_landing_page: Setting.trends_as_landing_page,
      status_page_url: Setting.status_page_url,
      sso_redirect: sso_redirect,
      dtl_tag: DTL_ENABLED ? DTL_TAG : nil,
      enable_local_privacy: Setting.enable_public_unlisted_visibility,
      enable_local_timeline: Setting.enable_local_timeline,
    }

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:unfollow_modal]    = object.current_account.user.setting_unfollow_modal
      store[:boost_modal]       = object.current_account.user.setting_boost_modal
      store[:delete_modal]      = object.current_account.user.setting_delete_modal
      store[:auto_play_gif]     = object.current_account.user.setting_auto_play_gif
      store[:display_media]     = object.current_account.user.setting_display_media
      store[:display_media_expand] = object.current_account.user.setting_display_media_expand
      store[:expand_spoilers] = object.current_account.user.setting_expand_spoilers
      store[:enable_emoji_reaction] = object.current_account.user.setting_enable_emoji_reaction && Setting.enable_emoji_reaction
      store[:show_emoji_reaction_on_timeline] = object.current_account.user.setting_show_emoji_reaction_on_timeline
      store[:enable_login_privacy] = object.current_account.user.setting_enable_login_privacy
      store[:enable_dtl_menu] = object.current_account.user.setting_enable_dtl_menu
      store[:hide_recent_emojis] = object.current_account.user.setting_hide_recent_emojis
      store[:reduce_motion]     = object.current_account.user.setting_reduce_motion
      store[:disable_swiping]   = object.current_account.user.setting_disable_swiping
      store[:advanced_layout]   = object.current_account.user.setting_advanced_layout
      store[:use_blurhash]      = object.current_account.user.setting_use_blurhash
      store[:use_pending_items] = object.current_account.user.setting_use_pending_items
      store[:show_trends]       = Setting.trends && object.current_account.user.setting_trends
      store[:bookmark_category_needed] = object.current_account.user.setting_bookmark_category_needed
      store[:simple_timeline_menu] = object.current_account.user.setting_simple_timeline_menu
      store[:show_quote_in_home] = object.current_account.user.setting_show_quote_in_home
      store[:show_quote_in_public] = object.current_account.user.setting_show_quote_in_public
      store[:hide_blocking_quote] = object.current_account.user.setting_hide_blocking_quote
      store[:hide_emoji_reaction_unavailable_server] = object.current_account.user.setting_hide_emoji_reaction_unavailable_server
    else
      store[:auto_play_gif] = Setting.auto_play_gif
      store[:display_media] = Setting.display_media
      store[:reduce_motion] = Setting.reduce_motion
      store[:use_blurhash]  = Setting.use_blurhash
      store[:enable_emoji_reaction] = Setting.enable_emoji_reaction
      store[:show_emoji_reaction_on_timeline] = Setting.enable_emoji_reaction
      store[:show_quote_in_home] = true
      store[:show_quote_in_public] = true
    end

    store[:disabled_account_id] = object.disabled_account.id.to_s if object.disabled_account
    store[:moved_to_account_id] = object.moved_to_account.id.to_s if object.moved_to_account

    store[:owner] = object.owner&.id&.to_s if Rails.configuration.x.single_user_mode

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                    = object.current_account.id.to_s
      store[:default_privacy]       = object.visibility || object.current_account.user.setting_default_privacy
      store[:stay_privacy]          = object.current_account.user.setting_stay_privacy
      store[:default_searchability] = object.searchability || object.current_account.user.setting_default_searchability
      store[:default_sensitive]     = object.current_account.user.setting_default_sensitive
      store[:default_language]      = object.current_account.user.preferred_posting_language
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}

    ActiveRecord::Associations::Preloader.new(
      records: [object.current_account, object.admin, object.owner, object.disabled_account, object.moved_to_account].compact,
      associations: [:account_stat, :user, { moved_to_account: [:account_stat, :user] }]
    )

    store[object.current_account.id.to_s]  = ActiveModelSerializers::SerializableResource.new(object.current_account, serializer: REST::AccountSerializer) if object.current_account
    store[object.admin.id.to_s]            = ActiveModelSerializers::SerializableResource.new(object.admin, serializer: REST::AccountSerializer) if object.admin
    store[object.owner.id.to_s]            = ActiveModelSerializers::SerializableResource.new(object.owner, serializer: REST::AccountSerializer) if object.owner
    store[object.disabled_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.disabled_account, serializer: REST::AccountSerializer) if object.disabled_account
    store[object.moved_to_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.moved_to_account, serializer: REST::AccountSerializer) if object.moved_to_account

    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment.supported_file_extensions + MediaAttachment.supported_mime_types }
  end

  def languages
    LanguagesHelper::SUPPORTED_LOCALES.map { |(key, value)| [key, value[0], value[1]] }
  end

  private

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end

  def sso_redirect
    "/auth/auth/#{Devise.omniauth_providers[0]}" if ENV['ONE_CLICK_SSO_LOGIN'] == 'true' && ENV['OMNIAUTH_ONLY'] == 'true' && Devise.omniauth_providers.length == 1
  end
end
