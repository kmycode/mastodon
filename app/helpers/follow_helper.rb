# frozen_string_literal: true

module FollowHelper
  def request_pending_follow?(source_account, target_account)
    target_account.locked? || source_account.silenced? || block_straight_follow?(source_account) ||
      ((source_account.bot? || proxy_account?(source_account)) && target_account.user&.setting_lock_follow_from_bot)
  end

  def block_straight_follow?(account)
    return false if account.local?

    DomainBlock.reject_straight_follow?(account.domain)
  end

  def proxy_account?(account)
    (account.username.downcase.include?('_proxy') ||
     account.username.downcase.end_with?('proxy') ||
     account.username.downcase.include?('_bot_') ||
     account.username.downcase.end_with?('bot') ||
     account.display_name&.downcase&.include?('proxy') ||
     account.display_name&.include?('プロキシ') ||
     account.note&.include?('プロキシ')) &&
      (account.following_count.zero? || account.following_count > account.followers_count) &&
      proxyable_software?(account)
  end

  def proxyable_software?(account)
    return false if account.local?

    info = InstanceInfo.find_by(domain: account.domain)
    return false if info.nil?

    %w(misskey calckey firefish meisskey cherrypick sharkey).include?(info.software)
  end
end
