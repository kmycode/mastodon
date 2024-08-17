# frozen_string_literal: true

class NotificationGroup < ActiveModelSerializers::Model
  attributes :group_key, :sample_accounts, :notifications_count, :notification, :most_recent_notification_id, :emoji_reaction_groups, :list

  # Try to keep this consistent with `app/javascript/mastodon/models/notification_group.ts`
  SAMPLE_ACCOUNTS_SIZE = 8
  SAMPLE_ACCOUNTS_SIZE_FOR_EMOJI_REACTION = 40

  class NotificationEmojiReactionGroup < ActiveModelSerializers::Model
    attributes :emoji_reaction, :sample_accounts
  end

  def self.from_notification(notification, max_id: nil)
    if notification.group_key.present?
      # TODO: caching, and, if caching, preloading
      scope = notification.account.notifications.where(group_key: notification.group_key)
      scope = scope.where(id: ..max_id) if max_id.present?

      # Ideally, we would not load accounts for each notification group
      most_recent_notifications = scope.order(id: :desc).includes(:from_account, :list_status).take(SAMPLE_ACCOUNTS_SIZE)
      most_recent_id = most_recent_notifications.first.id
      sample_accounts = most_recent_notifications.map(&:from_account)
      emoji_reaction_groups = extract_emoji_reaction_pair(
        scope.order(id: :desc).includes(emoji_reaction: :account).take(SAMPLE_ACCOUNTS_SIZE_FOR_EMOJI_REACTION)
      )
      list = pick_list(most_recent_notifications)
      notifications_count = scope.count
    else
      most_recent_id = notification.id
      sample_accounts = [notification.from_account]
      emoji_reaction_groups = extract_emoji_reaction_pair([notification])
      list = pick_list([notification])
      notifications_count = 1
    end

    NotificationGroup.new(
      notification: notification,
      group_key: notification.group_key || "ungrouped-#{notification.id}",
      sample_accounts: sample_accounts,
      emoji_reaction_groups: emoji_reaction_groups,
      list: list,
      notifications_count: notifications_count,
      most_recent_notification_id: most_recent_id
    )
  end

  delegate :type,
           :target_status,
           :report,
           :account_relationship_severance_event,
           :account_warning,
           to: :notification, prefix: false

  def self.extract_emoji_reaction_pair(scope)
    return [] unless scope.first.type == :emoji_reaction

    scope = scope.filter { |g| g.emoji_reaction.present? }
    return [] if scope.empty?

    scope
      .each_with_object({}) { |e, h| h[e.emoji_reaction.name] = (h[e.emoji_reaction.name] || []).push(e.emoji_reaction) }
      .to_a
      .map { |pair| NotificationEmojiReactionGroup.new(emoji_reaction: pair[1].first, sample_accounts: pair[1].take(SAMPLE_ACCOUNTS_SIZE).map(&:account)) }
  end

  def self.pick_list(scope)
    return [] unless scope.first.type == :list_status

    scope = scope.filter { |g| g.list_status.present? }
    return [] if scope.empty?

    scope.first.list_status.list
  end
end
