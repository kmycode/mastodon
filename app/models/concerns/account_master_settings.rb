# frozen_string_literal: true

module AccountMasterSettings
  extend ActiveSupport::Concern

  included do
    def subscription_policy
      return master_settings['subscription_policy']&.to_sym || :allow if master_settings.present?

      # allow, followers_only, block
      :allow
    end

    def subscription_policy=(val)
      self.master_settings = (master_settings.nil? ? {} : master_settings).merge({ 'subscription_policy' => val })
    end

    def all_subscribable?
      subscription_policy == :allow
    end

    def public_master_settings
      {
        'subscription_policy' => subscription_policy,
      }
    end
  end
end
