# frozen_string_literal: true

module AccountMasterSettings
  extend ActiveSupport::Concern

  included do
    def subscribtion_policy
      return master_settings['subscribtion_policy']&.to_sym || :allow if master_settings.present?

      # allow, followers_only, block
      :allow
    end

    def all_subscribable?
      subscribtion_policy == :allow
    end

    def public_master_settings
      {
        'subscribtion_policy' => subscribtion_policy,
      }
    end
  end
end
