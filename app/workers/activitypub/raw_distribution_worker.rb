# frozen_string_literal: true

class ActivityPub::RawDistributionWorker
  include Sidekiq::Worker
  include Payloadable

  sidekiq_options queue: 'push'

  # Base worker for when you want to queue up a bunch of deliveries of
  # some payload. In this case, we have already generated JSON and
  # we are going to distribute it to the account's followers minus
  # the explicitly provided inboxes
  def perform(json, source_account_id, exclude_inboxes = [])
    @account         = Account.find(source_account_id)
    @json            = json
    @exclude_inboxes = exclude_inboxes

    distribute!
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def distribute!
    unless inboxes_for_misskey.empty?
      ActivityPub::DeliveryWorker.push_bulk(inboxes_for_misskey, limit: 1_000) do |inbox_url|
        [payload_for_misskey, source_account_id, inbox_url, options]
      end
    end

    unless inboxes_for_friend.empty?
      ActivityPub::DeliveryWorker.push_bulk(inboxes_for_friend, limit: 1_000) do |inbox_url|
        [payload_for_friend, source_account_id, inbox_url, options]
      end
    end

    return if inboxes.empty?

    ActivityPub::DeliveryWorker.push_bulk(inboxes, limit: 1_000) do |inbox_url|
      [payload, source_account_id, inbox_url, options]
    end
  end

  def payload
    @json
  end

  def payload_for_misskey
    payload
  end

  def payload_for_friend
    payload
  end

  def source_account_id
    @account.id
  end

  def inboxes
    @inboxes ||= @account.followers.inboxes - @exclude_inboxes
  end

  def inboxes_for_misskey
    []
  end

  def inboxes_for_friend
    []
  end

  def options
    {}
  end
end
