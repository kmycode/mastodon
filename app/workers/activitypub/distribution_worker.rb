# frozen_string_literal: true

class ActivityPub::DistributionWorker < ActivityPub::RawDistributionWorker
  # Skip followers synchronization for accounts with a large number of followers,
  # as this is expensive and people with very large amounts of followers
  # necessarily have less control over them to begin with
  MAX_FOLLOWERS_FOR_SYNCHRONIZATION = 25_000

  # Distribute a new status or an edit of a status to all the places
  # where the status is supposed to go or where it was interacted with
  def perform(status_id)
    @status  = Status.find(status_id)
    @account = @status.account

    if @status.limited_visibility?
      distribute_limited!
    else
      distribute!
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def distribute_limited!
    if @status.reply? && @status.conversation.present? && !@status.conversation.local?
      distribute_conversation!
    else
      distribute_limited_mentions!
    end
  end

  def distribute_limited_mentions!
    ActivityPub::DeliveryWorker.push_bulk(inboxes_for_limited, limit: 1_000) do |inbox_url|
      [payload, @account.id, inbox_url, options]
    end
  end

  def distribute_conversation!
    inbox_url = @status.conversation.inbox_url
    return if inbox_url.blank?

    ActivityPub::DeliveryWorker.perform_async(payload, @account.id, inbox_url, options)
  end

  def inboxes
    @inboxes ||= status_reach_finder.inboxes
  end

  def inboxes_for_misskey
    @inboxes_for_misskey ||= status_reach_finder.inboxes_for_misskey
  end

  def inboxes_for_friend
    @inboxes_for_friend ||= status_reach_finder.inboxes_for_friend
  end

  def inboxes_for_limited
    @inboxes_for_limited ||= status_reach_finder.inboxes_for_limited
  end

  def status_reach_finder
    @status_reach_finder ||= StatusReachFinder.new(@status)
  end

  def payload
    @payload ||= Oj.dump(serialize_payload(@status, activity_serializer, serializer_options.merge(signer: @account, always_sign_unsafe: always_sign)))
  end

  def payload_for_misskey
    @payload_for_misskey ||= Oj.dump(serialize_payload(@status, activity_serializer, serializer_options.merge(signer: @account, for_misskey: true)))
  end

  def payload_for_friend
    @payload_for_friend ||= Oj.dump(serialize_payload(@status, activity_serializer, serializer_options.merge(signer: @account, for_friend: true, always_sign_unsafe: always_sign)))
  end

  def activity_serializer
    @status.reblog? ? ActivityPub::AnnounceNoteSerializer : ActivityPub::CreateNoteSerializer
  end

  def serializer_options
    {}
  end

  def always_sign
    false
  end

  def options
    { 'synchronize_followers' => @status.private_visibility? && @account.followers_count < MAX_FOLLOWERS_FOR_SYNCHRONIZATION }
  end
end
