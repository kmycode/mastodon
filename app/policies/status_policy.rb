# frozen_string_literal: true

class StatusPolicy < ApplicationPolicy
  def initialize(current_account, record, preloaded_relations = {}, preloaded_status_relations = {})
    super(current_account, record)

    @preloaded_relations = preloaded_relations
    @preloaded_status_relations = preloaded_status_relations
  end

  delegate :reply?, :expired?, to: :record

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

  def reblog?
    !requires_mention? && (!private? || owned?) && show? && !blocking_author?
  end

  def favourite?
    show? && !blocking_author?
  end

  def emoji_reaction?
    show? && !blocking_author?
  end

  def quote?
    %i(public public_unlisted unlisted).include?(record.visibility.to_sym) && show? && !blocking_author?
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
      record.mentions.where(account: current_account).exists?
    end
  end

  def author_blocking_domain?
    return false if current_account.nil? || current_account.domain.nil?

    author.domain_blocking?(current_account.domain)
  end

  def blocking_author?
    return false if current_account.nil?

    @preloaded_relations[:blocking] ? @preloaded_relations[:blocking][author.id] : current_account.blocking?(author)
  end

  def author_blocking?
    return false if current_account.nil?

    @preloaded_relations[:blocked_by] ? @preloaded_relations[:blocked_by][author.id] : author.blocking?(current_account)
  end

  def following_author?
    return false if current_account.nil?

    @preloaded_relations[:following] ? @preloaded_relations[:following][author.id] : current_account.following?(author)
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
    @domain_block ||= DomainBlock.find_by(domain: current_account&.domain)
    if @domain_block
      if status.account.user&.setting_send_without_domain_blocks
        (@domain_block.detect_invalid_subscription && status.public_unlisted_visibility? && status.account.user&.setting_reject_public_unlisted_subscription) ||
          (@domain_block.detect_invalid_subscription && status.public_visibility? && status.account.user&.setting_reject_unlisted_subscription)
      else
        (@domain_block.reject_send_not_public_searchability && status.compute_searchability != 'public') ||
          (@domain_block.reject_send_public_unlisted && status.public_unlisted_visibility?) ||
          (@domain_block.reject_send_dissubscribable && !status.account.all_subscribable?) ||
          (@domain_block.detect_invalid_subscription && status.public_unlisted_visibility? && status.account.user&.setting_reject_public_unlisted_subscription) ||
          (@domain_block.detect_invalid_subscription && status.public_visibility? && status.account.user&.setting_reject_unlisted_subscription) ||
          (@domain_block.reject_send_media && status.with_media?) ||
          (@domain_block.reject_send_sensitive && ((status.with_media? && status.sensitive) || status.spoiler_text?))
      end
    else
      false
    end
  end
end
