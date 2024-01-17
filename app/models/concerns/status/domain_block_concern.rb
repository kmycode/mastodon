# frozen_string_literal: true

module Status::DomainBlockConcern
  extend ActiveSupport::Concern

  def sending_sensitive?
    return false unless local?

    (with_media? && sensitive) || spoiler_text?
  end

  def sending_maybe_compromised_privacy?
    return false unless local?

    (public_unlisted_visibility? && public_searchability? && account.user&.setting_reject_public_unlisted_subscription) ||
      (unlisted_visibility? && public_searchability? && account.user&.setting_reject_unlisted_subscription)
  end
end
