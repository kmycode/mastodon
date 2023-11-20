# frozen_string_literal: true

class ActivityPub::ForwardConversationWorker
  include Sidekiq::Worker

  def perform(payload, status_id)
    @status  = Status.find(status_id)
    @payload = payload

    return unless @status.conversation.present? && @status.conversation.local? && @status.conversation.ancestor_status.present?
    return unless @status.limited_visibility?

    @account = @status.conversation.ancestor_status.account

    distribute_limited_mentions!
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def distribute_limited_mentions!
    ActivityPub::DeliveryWorker.push_bulk(inboxes_for_limited, limit: 1_000) do |inbox_url|
      [payload, @account.id, inbox_url, options]
    end
  end

  def inboxes_for_limited
    DeliveryFailureTracker.without_unavailable(
      Account.remote.merge(@status.mentioned_accounts).pluck(:inbox_url).compact_blank.uniq
    )
  end

  def options
    { 'synchronize_followers' => @status.private_visibility? }
  end

  attr_reader :payload
end
