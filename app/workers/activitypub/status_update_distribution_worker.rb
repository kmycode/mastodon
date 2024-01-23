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
      distribute_delete_activity!
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def inboxes
    return super if @status.limited_visibility?
    return super unless sensitive?

    super - inboxes_diff_for_sending_domain_block
  end

  def inboxes_diff_for_sending_domain_block
    status_reach_finder.inboxes_diff_for_sending_domain_block
  end

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

  def delete_activity
    @delete_activity ||= Oj.dump(serialize_payload(@status, ActivityPub::DeleteSerializer, signer: @account))
  end

  def distribute_delete_activity!
    return unless sensitive_changed?

    target_inboxes = inboxes_diff_for_sending_domain_block
    return if target_inboxes.empty?

    ActivityPub::DeliveryWorker.push_bulk(target_inboxes, limit: 1_000) do |inbox_url|
      [delete_activity, @account.id, inbox_url, {}]
    end
  end

  def always_sign
    @status.limited_visibility?
  end

  def sensitive?
    @options[:sensitive]
  end

  def sensitive_changed?
    @options[:sensitive_changed]
  end
end
