# frozen_string_literal: true

class UpdateAccountService < BaseService
  def call(account, params, raise_error: false)
    was_locked    = account.locked
    update_method = raise_error ? :update! : :update

    if account.user && params.key?(:bio_markdown)
      user_params = { settings_attributes: { bio_markdown: params['bio_markdown'] } }
      params.delete(:bio_markdown)
      account.user.send(update_method, user_params)
    end

    account.send(update_method, params).tap do |ret|
      next unless ret

      authorize_all_follow_requests(account) if was_locked && !account.locked
      check_links(account)
      process_hashtags(account)
    end
  rescue Mastodon::DimensionsValidationError, Mastodon::StreamValidationError => e
    account.errors.add(:avatar, e.message)
    false
  end

  private

  def authorize_all_follow_requests(account)
    follow_requests = FollowRequest.where(target_account: account)
    follow_requests = follow_requests.preload(:account).reject { |req| req.account.silenced? || reject_straight_follow_domains.include?(req.account.domain) }
    AuthorizeFollowWorker.push_bulk(follow_requests, limit: 1_000) do |req|
      [req.account_id, req.target_account_id]
    end
  end

  def reject_straight_follow_domains
    DomainBlock.where(reject_straight_follow: true).pluck(:domain)
  end

  def check_links(account)
    return unless account.fields.any?(&:requires_verification?)

    VerifyAccountLinksWorker.perform_async(account.id)
  end

  def process_hashtags(account)
    account.tags_as_strings = Extractor.extract_hashtags(account.note)
  end
end
