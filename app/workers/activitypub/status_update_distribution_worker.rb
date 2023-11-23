# frozen_string_literal: true

class ActivityPub::StatusUpdateDistributionWorker < ActivityPub::DistributionWorker
  # Distribute an profile update to servers that might have a copy
  # of the account in question
  def perform(status_id, options = {})
    @options = options.with_indifferent_access
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

  def inboxes_for_limited
    @inboxes_for_limited ||= @status.mentioned_accounts.inboxes
  end

  def build_activity(for_misskey: false, for_friend: false)
    ActivityPub::ActivityPresenter.new(
      id: [ActivityPub::TagManager.instance.uri_for(@status), '#updates/', @status.edited_at.to_i].join,
      type: 'Update',
      actor: ActivityPub::TagManager.instance.uri_for(@status.account),
      published: @status.edited_at,
      to: for_friend ? ActivityPub::TagManager.instance.to_for_friend(@status) : ActivityPub::TagManager.instance.to(@status),
      cc: for_misskey ? ActivityPub::TagManager.instance.cc_for_misskey(@status) : ActivityPub::TagManager.instance.cc(@status),
      virtual_object: @status
    )
  end

  def activity
    build_activity
  end

  def activity_for_misskey
    build_activity(for_misskey: true)
  end

  def activity_for_friend
    build_activity(for_friend: true)
  end
end
