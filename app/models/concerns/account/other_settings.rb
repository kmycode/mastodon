# frozen_string_literal: true

module Account::OtherSettings
  extend ActiveSupport::Concern

  included do
    def noindex?
      user_prefers_noindex? || (settings.present? && settings['noindex']) || false
    end

    def noai?
      user&.setting_noai || (settings.present? && settings['noai']) || false
    end

    def translatable_private?
      user&.setting_translatable_private || (settings.present? && settings['translatable_private']) || false
    end

    def link_preview?
      return user.setting_link_preview if local? && user.present?
      return settings['link_preview'] if settings.present? && settings.key?('link_preview')

      true
    end

    def allow_quote?
      return user.setting_allow_quote if local? && user.present?
      return settings['allow_quote'] if settings.present? && settings.key?('allow_quote')

      true
    end

    def hide_statuses_count?
      return user&.setting_hide_statuses_count unless user&.setting_hide_statuses_count.nil?
      return settings['hide_statuses_count'] if settings.present?

      false
    end

    def hide_following_count?
      return user&.setting_hide_following_count unless user&.setting_hide_following_count.nil?
      return settings['hide_following_count'] if settings.present?

      false
    end

    def hide_followers_count?
      return user&.setting_hide_followers_count unless user&.setting_hide_followers_count.nil?
      return settings['hide_followers_count'] if settings.present?

      false
    end

    def emoji_reaction_policy
      return settings['emoji_reaction_policy']&.to_sym || :allow if settings.present? && user.nil?
      return :allow if user.nil?
      return :block if local? && !Setting.enable_emoji_reaction

      user.setting_emoji_reaction_policy&.to_sym
    end

    def show_emoji_reaction?(account)
      return false unless Setting.enable_emoji_reaction
      return true if local? && account&.local? && user.setting_slip_local_emoji_reaction

      case emoji_reaction_policy
      when :block
        false
      when :following_only
        account.present? && (id == account.id || following?(account))
      when :followers_only
        account.present? && (id == account.id || followed_by?(account))
      when :mutuals_only
        account.present? && (id == account.id || mutual?(account))
      when :outside_only
        account.present? && (id == account.id || following?(account) || followed_by?(account))
      else
        true
      end
    end

    def allow_emoji_reaction?(account)
      return false if account.nil?
      return true unless local? || account.local?

      show_emoji_reaction?(account)
    end

    def public_settings
      # Please update `app/javascript/mastodon/api_types/accounts.ts` when making changes to the attributes
      config = {
        'noindex' => noindex?,
        'noai' => noai?,
        'hide_network' => hide_collections,
        'hide_statuses_count' => hide_statuses_count?,
        'hide_following_count' => hide_following_count?,
        'hide_followers_count' => hide_followers_count?,
        'translatable_private' => translatable_private?,
        'link_preview' => link_preview?,
        'allow_quote' => allow_quote?,
        'emoji_reaction_policy' => Setting.enable_emoji_reaction ? emoji_reaction_policy : :block,
      }
      config = config.merge(settings) if settings.present?
      config
    end

    def public_settings_for_local
      s = public_settings
      s = s.merge({ 'emoji_reaction_policy' => 'allow' }) if local? && user&.setting_slip_local_emoji_reaction
      s.merge(public_master_settings)
    end
  end
end
