# frozen_string_literal: true

class StatusPolicy < ApplicationPolicy
  def show?
    return false if author.unavailable?

    if requires_mention?
      owned? || mention_exists?
    elsif login?
      owned? || !current_account.nil?
    elsif private?
      owned? || following_author? || mention_exists?
    else
      current_account.nil? || (!author_blocking? && !author_blocking_domain? && !server_blocking_domain?)
    end
  end

  def show_mentioned_users?
    record.limited_visibility? ? owned_conversation? : owned?
  end

  def show_activity?
    return false unless show?
    return true unless record.expires?

    following_author_domain?
  end

  def quote?
    show? && !blocking_author? && record.quote_policy_for_account(current_account) != :denied
  end

  def reblog?
    !requires_mention? && (!private? || owned?) && show? && !blocking_author?
  end

  def favourite?
    show? && !blocking_author?
  end

  def emoji_reaction?
    show? && !blocking_author?
  end

  def destroy?
    owned?
  end

  alias unreblog? destroy?

  def update?
    owned?
  end

  private

  def requires_mention?
    record.direct_visibility? || record.limited_visibility?
  end

  def owned?
    author.id == current_account&.id
  end

  def owned_conversation?
    record.conversation&.local? &&
      (record.conversation.ancestor_status.nil? ? owned? : record.conversation.ancestor_status.account_id == current_account&.id)
  end

  def private?
    record.private_visibility?
  end

  def login?
    record.login_visibility?
  end

  def public?
    record.public_visibility? || record.public_unlisted_visibility?
  end

  def mention_exists?
    return false if current_account.nil?

    if record.mentions.loaded?
      record.mentions.any? { |mention| mention.account_id == current_account.id }
    else
      record.mentions.exists?(account: current_account)
    end
  end

  def author_blocking_domain?
    return false if current_account.nil? || current_account.domain.nil?

    author.domain_blocking?(current_account.domain)
  end

  def blocking_author?
    return false if current_account.nil?

    current_account.blocking?(author)
  end

  def author_blocking?
    return false if current_account.nil?

    current_account.blocked_by?(author)
  end

  def following_author?
    return false if current_account.nil?

    current_account.following?(author)
  end

  def following_author_domain?
    return false if current_account.nil?

    author.followed_by_domain?(current_account.domain, record.created_at)
  end

  def author
    record.account
  end

  def server_blocking_domain?
    if record.reblog? && record.reblog.local?
      server_blocking_domain_of_status?(record) || server_blocking_domain_of_status?(record.reblog)
    else
      server_blocking_domain_of_status?(record)
    end
  end

  def server_blocking_domain_of_status?(status)
    @domain_block = DomainBlock.find_by(domain: current_account&.domain) unless defined?(@domain_block)
    if @domain_block
      (@domain_block.detect_invalid_subscription && status.sending_maybe_compromised_privacy?) ||
        (@domain_block.reject_send_sensitive && status.sending_sensitive?)
    else
      false
    end
  end
end
