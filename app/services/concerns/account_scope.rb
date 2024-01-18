# frozen_string_literal: true

module AccountScope
  def scope_status(status)
    case status.visibility.to_sym
    when :public, :unlisted, :public_unlisted, :login
      scope_local
    when :private
      scope_account_local_followers(status.account)
    when :limited
      scope_status_all_mentioned(status)
    else
      scope_status_mentioned(status)
    end
  end

  def scope_local
    Account.local.select(:id)
  end

  def scope_account_local_followers(account)
    account.followers_for_local_distribution.or(Account.where(id: account.id)).select(:id).reorder(nil)
  end

  def scope_status_mentioned(status)
    Account.local.where(id: status.active_mentions.select(:account_id)).reorder(nil)
  end

  def scope_status_all_mentioned(status)
    Account.local.where(id: status.mentions.select(:account_id)).reorder(nil)
  end

  # TODO: not work
  def scope_list_following_account(account)
    account.lists_for_local_distribution.select(:id).reorder(nil)
  end

  def scope_tag_following_account(_status)
    TagFollow.where(tag_id: @status.tags.map(&:id)).select('account_id AS id').reorder(nil)
  end
end
