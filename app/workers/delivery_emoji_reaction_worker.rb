# frozen_string_literal: true

class DeliveryEmojiReactionWorker
  include Sidekiq::Worker
  include Redisable
  include Lockable
  include AccountScope

  sidekiq_options queue: 'perishable'

  def perform(payload_json, status_id, reacted_account_id)
    return unless Setting.enable_emoji_reaction

    status = Status.find(status_id)
    reacted_account = Account.find(reacted_account_id)

    if status.present?
      scope = scope_status(status)

      policy = status.account.emoji_reaction_policy
      return if policy == :block

      scope.select(:id).merge(policy_scope(status.account, policy)).includes(:user).find_each do |account|
        next if account.user.present? && (account.user.setting_stop_emoji_reaction_streaming || !account.user.setting_enable_emoji_reaction)
        next unless redis.exists?("subscribed:timeline:#{account.id}")
        next if !reacted_account.local? && account.excluded_from_timeline_domains.include?(reacted_account.domain)

        redis.publish("timeline:#{account.id}", payload_json)
      end
    end

    true
  rescue ActiveRecord::RecordNotFound
    true
  end

  def policy_scope(account, policy)
    case policy
    when :block
      Account.where(id: 0)
    when :mutuals_only
      account.mutuals.local.or(Account.where(id: account))
    when :following_only
      account.following.local.or(Account.where(id: account))
    when :followers_only
      account.followers.local.or(Account.where(id: account))
    when :outside_only
      account.followers.local.or(Account.where(id: account.following.local)).or(Account.where(id: account))
    else
      Account.local
    end
  end
end
