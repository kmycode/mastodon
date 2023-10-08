# frozen_string_literal: true

class StatusReachFinder
  # @param [Status] status
  # @param [Hash] options
  # @option options [Boolean] :unsafe
  def initialize(status, options = {})
    @status  = status
    @options = options
  end

  def inboxes
    (reached_account_inboxes + followers_inboxes + relay_inboxes).uniq
  end

  def inboxes_for_misskey
    if banned_domains_for_misskey.empty?
      []
    else
      (reached_account_inboxes_for_misskey + followers_inboxes_for_misskey).uniq
    end
  end

  def inboxes_for_friend
    (reached_account_inboxes_for_friend + followers_inboxes_for_friend + friend_inboxes).uniq
  end

  private

  def reached_account_inboxes
    # When the status is a reblog, there are no interactions with it
    # directly, we assume all interactions are with the original one

    if @status.reblog?
      []
    elsif @status.limited_visibility?
      Account.where(id: mentioned_account_ids).where.not(domain: banned_domains).inboxes
    else
      Account.where(id: reached_account_ids).where.not(domain: banned_domains + friend_domains).inboxes
    end
  end

  def reached_account_inboxes_for_misskey
    if @status.reblog?
      []
    elsif @status.limited_visibility?
      Account.where(id: mentioned_account_ids).where(domain: banned_domains_for_misskey).inboxes
    else
      Account.where(id: reached_account_ids).where(domain: banned_domains_for_misskey - friend_domains).inboxes
    end
  end

  def reached_account_inboxes_for_friend
    if @status.reblog?
      []
    elsif @status.limited_visibility?
      Account.where(id: mentioned_account_ids).where.not(domain: banned_domains).inboxes
    else
      Account.where(id: reached_account_ids, domain: friend_domains).where.not(domain: banned_domains - friend_domains).inboxes
    end
  end

  def reached_account_ids
    [
      replied_to_account_id,
      reblog_of_account_id,
      mentioned_account_ids,
      reblogs_account_ids,
      favourites_account_ids,
      replies_account_ids,
      quoted_account_id,
    ].tap do |arr|
      arr.flatten!
      arr.compact!
      arr.uniq!
    end
  end

  def replied_to_account_id
    @status.in_reply_to_account_id if distributable?
  end

  def reblog_of_account_id
    @status.reblog.account_id if @status.reblog?
  end

  def mentioned_account_ids
    @status.mentions.pluck(:account_id)
  end

  # Beware: Reblogs can be created without the author having had access to the status
  def reblogs_account_ids
    @status.reblogs.rewhere(deleted_at: [nil, @status.deleted_at]).pluck(:account_id) if distributable? || unsafe?
  end

  # Beware: Favourites can be created without the author having had access to the status
  def favourites_account_ids
    @status.favourites.pluck(:account_id) if distributable? || unsafe?
  end

  # Beware: Replies can be created without the author having had access to the status
  def replies_account_ids
    @status.replies.pluck(:account_id) if distributable? || unsafe?
  end

  def quoted_account_id
    @status.quote.account_id if @status.quote?
  end

  def followers_inboxes
    if @status.in_reply_to_local_account? && distributable?
      @status.account.followers.or(@status.thread.account.followers.not_domain_blocked_by_account(@status.account)).where.not(domain: banned_domains + friend_domains).inboxes
    elsif @status.direct_visibility? || @status.limited_visibility?
      []
    else
      @status.account.followers.where.not(domain: banned_domains + friend_domains).inboxes
    end
  end

  def followers_inboxes_for_misskey
    if @status.in_reply_to_local_account? && distributable?
      @status.account.followers.or(@status.thread.account.followers.not_domain_blocked_by_account(@status.account)).where(domain: banned_domains_for_misskey - friend_domains).inboxes
    elsif @status.direct_visibility? || @status.limited_visibility?
      []
    else
      @status.account.followers.where(domain: banned_domains_for_misskey - friend_domains).inboxes
    end
  end

  def followers_inboxes_for_friend
    if @status.in_reply_to_local_account? && distributable?
      @status.account.followers.or(@status.thread.account.followers.not_domain_blocked_by_account(@status.account)).where(domain: friend_domains).inboxes
    elsif @status.direct_visibility? || @status.limited_visibility?
      []
    else
      @status.account.followers.where(domain: friend_domains).inboxes
    end
  end

  def relay_inboxes
    if @status.public_visibility?
      Relay.enabled.pluck(:inbox_url)
    else
      []
    end
  end

  def friend_inboxes
    if @status.public_visibility? || @status.public_unlisted_visibility? || (@status.unlisted_visibility? && (@status.public_searchability? || @status.public_unlisted_searchability?))
      DeliveryFailureTracker.without_unavailable(FriendDomain.distributables.pluck(:inbox_url))
    else
      []
    end
  end

  def distributable?
    @status.public_visibility? || @status.unlisted_visibility? || @status.public_unlisted_visibility?
  end

  def unsafe?
    @options[:unsafe]
  end

  def friend_domains
    return @friend_domains if defined?(@friend_domains)

    @friend_domains = FriendDomain.deliver_locals.pluck(:domain)
    @friend_domains -= UnavailableDomain.where(domain: @friend_domains).pluck(:domain)
  end

  def banned_domains
    return @banned_domains if @banned_domains

    domains = banned_domains_of_status(@status)
    domains += banned_domains_of_status(@status.reblog) if @status.reblog? && @status.reblog.local?
    @banned_domains = domains.uniq + banned_domains_for_misskey
  end

  def banned_domains_of_status(status)
    if status.account.user&.setting_send_without_domain_blocks
      []
    else
      blocks = DomainBlock.where(domain: nil)
      blocks = blocks.or(DomainBlock.where(reject_send_not_public_searchability: true)) if status.compute_searchability != 'public'
      blocks = blocks.or(DomainBlock.where(reject_send_public_unlisted: true)) if status.public_unlisted_visibility?
      blocks = blocks.or(DomainBlock.where(reject_send_dissubscribable: true)) if status.account.dissubscribable
      blocks = blocks.or(DomainBlock.where(reject_send_media: true)) if status.with_media?
      blocks = blocks.or(DomainBlock.where(reject_send_sensitive: true)) if (status.with_media? && status.sensitive) || status.spoiler_text?
      blocks.pluck(:domain).uniq
    end
  end

  def banned_domains_for_misskey
    return @banned_domains_for_misskey if @banned_domains_for_misskey

    return @banned_domains_for_misskey = [] if (!@status.account.user&.setting_reject_public_unlisted_subscription && !@status.account.user&.setting_reject_unlisted_subscription) || (!@status.public_unlisted_visibility? && !@status.unlisted_visibility?)

    domains = banned_domains_for_misskey_of_status(@status)
    domains += banned_domains_for_misskey_of_status(@status.reblog) if @status.reblog? && @status.reblog.local?
    @banned_domains_for_misskey = domains.uniq
  end

  def banned_domains_for_misskey_of_status(status)
    return [] if status.public_searchability?
    return [] unless (status.public_unlisted_visibility? && status.account.user&.setting_reject_public_unlisted_subscription) || (status.unlisted_visibility? && status.account.user&.setting_reject_unlisted_subscription)

    from_info = InstanceInfo.where(software: %w(misskey calckey cherrypick)).pluck(:domain)
    from_domain_block = DomainBlock.where(detect_invalid_subscription: true).pluck(:domain)
    (from_info + from_domain_block).uniq
  end
end
