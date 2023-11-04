# frozen_string_literal: true

class ActivityPub::EmojiReactionDistributionWorker < ActivityPub::RawDistributionWorker
  # Distribute an emoji reaction to servers that might have a copy of ohagi
  def perform(emoji_reaction_id, options = {})
    @options = options.with_indifferent_access
    @emoji_reaction = EmojiReaction.find(emoji_reaction_id)
    @account = @emoji_reaction.account
    @status = @emoji_reaction.status

    distribute!
  rescue ActiveRecord::RecordNotFound
    true
  end

  protected

  def payload
    @payload ||= Oj.dump(serialize_payload(@emoji_reaction, ActivityPub::EmojiReactionSerializer, signer: @account))
  end

  def inboxes
    @inboxes ||= (@account.followers.inboxes + [@status.account.preferred_inbox_url].compact_blank + relay_inboxes + friend_inboxes).uniq
  end

  def relay_inboxes
    if @status.public_visibility?
      Relay.enabled.pluck(:inbox_url)
    else
      []
    end
  end

  def friend_inboxes
    if @status.distributable_friend?
      DeliveryFailureTracker.without_unavailable(FriendDomain.distributables.where(delivery_local: true).where.not(domain: AccountDomainBlock.where(account: @status.account).select(:domain)).pluck(:inbox_url))
    else
      []
    end
  end
end
