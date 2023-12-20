# frozen_string_literal: true

module Account::OtherSettings
  extend ActiveSupport::Concern

  included do
    def noindex?
      user_prefers_noindex? || (settings.present? && settings['noindex']) || false
    end

    def noai?
      return user.setting_noai if local? && user.present?
      return settings['noai'] if settings.present? && settings.key?('noai')

      false
    end

    def translatable_private?
      return user.setting_translatable_private if local? && user.present?
      return settings['translatable_private'] if settings.present? && settings.key?('translatable_private')

      false
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
      return user&.setting_hide_statuses_count if local? && user.present?
      return settings['hide_statuses_count'] if settings.present? && settings.key?('hide_statuses_count')

      false
    end

    def hide_following_count?
      return user&.setting_hide_following_count if local? && user.present?
      return settings['hide_following_count'] if settings.present? && settings.key?('hide_following_count')

      false
    end

    def hide_followers_count?
      return user&.setting_hide_followers_count if local? && user.present?
      return settings['hide_followers_count'] if settings.present? && settings.key?('hide_followers_count')

      false
    end

    def emoji_reaction_policy
      return :block if !local? && Setting.emoji_reaction_disallow_domains&.include?(domain)
      return settings['emoji_reaction_policy']&.to_sym || :allow if settings.present? && !local?
      return :allow if user.nil?
      return :block if local? && !Setting.enable_emoji_reaction # for federation

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
      {
        'noindex' => noindex?,
        'noai' => noai?,
        'hide_network' => hide_collections,
        'hide_statuses_count' => hide_statuses_count?,
        'hide_following_count' => hide_following_count?,
        'hide_followers_count' => hide_followers_count?,
        'translatable_private' => translatable_private?,
        'link_preview' => link_preview?,
        'allow_quote' => allow_quote?,
        'emoji_reaction_policy' => Setting.enable_emoji_reaction ? emoji_reaction_policy.to_s : 'block',
      }
    end

    def public_settings_for_local
      s = public_settings
      s = s.merge({ 'emoji_reaction_policy' => 'allow' }) if local? && user&.setting_slip_local_emoji_reaction
      s.merge(public_master_settings)
    end
  end
end
