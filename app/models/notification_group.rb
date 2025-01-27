# frozen_string_literal: true

class NotificationGroup < ActiveModelSerializers::Model
  attributes :group_key, :sample_accounts, :notifications_count, :notification, :most_recent_notification_id, :pagination_data, :emoji_reaction_groups, :list

  # Try to keep this consistent with `app/javascript/mastodon/models/notification_group.ts`
  SAMPLE_ACCOUNTS_SIZE = 8
  SAMPLE_ACCOUNTS_SIZE_FOR_EMOJI_REACTION = 40

  class NotificationEmojiReactionGroup < ActiveModelSerializers::Model
    attributes :emoji_reaction, :sample_accounts
  end

  def self.from_notifications(notifications, pagination_range: nil, grouped_types: nil)
    return [] if notifications.empty?

    grouped_types = grouped_types.presence&.map(&:to_sym) || Notification::GROUPABLE_NOTIFICATION_TYPES

    grouped_notifications = notifications.filter { |notification| notification.group_key.present? && grouped_types.include?(notification.type) }
    group_keys = grouped_notifications.pluck(:group_key)

    with_emoji_reaction = grouped_notifications.any? { |notification| notification.type == :emoji_reaction }

    groups_data = load_groups_data(notifications.first.account_id, group_keys, pagination_range: pagination_range)
    accounts_map = Account.where(id: groups_data.values.pluck(1).flatten).index_by(&:id)

    notifications.map do |notification|
      if notification.group_key.present? && grouped_types.include?(notification.type)
        most_recent_notification_id, sample_account_ids, count, activity_ids, *raw_pagination_data = groups_data[notification.group_key]

        pagination_data = raw_pagination_data.empty? ? nil : { min_id: raw_pagination_data[0], latest_notification_at: raw_pagination_data[1] }

        emoji_reaction_groups = with_emoji_reaction ? convert_emoji_reaction_pair(activity_ids) : []

        NotificationGroup.new(
          notification: notification,
          group_key: notification.group_key,
          sample_accounts: sample_account_ids.map { |id| accounts_map[id] },
          notifications_count: count,
          most_recent_notification_id: most_recent_notification_id,
          pagination_data: pagination_data,
          emoji_reaction_groups: emoji_reaction_groups
        )
      else
        pagination_data = pagination_range.blank? ? nil : { min_id: notification.id, latest_notification_at: notification.created_at }

        emoji_reaction_groups = convert_emoji_reaction_pair([notification.activity_id])
        list = notification.type == :list_status ? notification.list_status&.list : nil

        NotificationGroup.new(
          notification: notification,
          group_key: "ungrouped-#{notification.id}",
          sample_accounts: [notification.from_account],
          notifications_count: 1,
          most_recent_notification_id: notification.id,
          pagination_data: pagination_data,
          emoji_reaction_groups: emoji_reaction_groups,
          list: list
        )
      end
    end
  end

  delegate :type,
           :target_status,
           :report,
           :account_relationship_severance_event,
           :account_warning,
           :generated_annual_report,
           to: :notification, prefix: false

  def self.convert_emoji_reaction_pair(activity_ids)
    return [] if activity_ids.empty?

    EmojiReaction.where(id: activity_ids)
                 .order(id: :desc)
                 .each_with_object({}) { |e, h| h[e.name] = (h[e.name] || []).push(e) }
                 .to_a
                 .map { |pair| NotificationEmojiReactionGroup.new(emoji_reaction: pair[1].first, sample_accounts: pair[1].take(SAMPLE_ACCOUNTS_SIZE).map(&:account)) }
  end

  class << self
    private

    def load_groups_data(account_id, group_keys, pagination_range: nil)
      return {} if group_keys.empty?

      if pagination_range.present?
        binds = [
          account_id,
          SAMPLE_ACCOUNTS_SIZE,
          ActiveRecord::Relation::QueryAttribute.new('group_keys', group_keys, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::String.new)),
          pagination_range.begin || 0,
        ]
        binds << pagination_range.end unless pagination_range.end.nil?

        upper_bound_cond = begin
          if pagination_range.end.nil?
            ''
          elsif pagination_range.exclude_end?
            'AND id < $5'
          else
            'AND id <= $5'
          end
        end

        ActiveRecord::Base.connection.select_all(<<~SQL.squish, 'grouped_notifications', binds).cast_values.to_h { |k, *values| [k, values] }
          SELECT
            groups.group_key,
            (SELECT id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key #{upper_bound_cond} ORDER BY id DESC LIMIT 1),
            array(SELECT from_account_id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key #{upper_bound_cond} ORDER BY id DESC LIMIT $2),
            (SELECT count(*) FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key #{upper_bound_cond}) AS notifications_count,
            array(SELECT activity_id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key #{upper_bound_cond} AND activity_type = 'EmojiReaction'),
            (SELECT id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key AND id >= $4 ORDER BY id ASC LIMIT 1) AS min_id,
            (SELECT created_at FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key #{upper_bound_cond} ORDER BY id DESC LIMIT 1)
          FROM
            unnest($3::text[]) AS groups(group_key);
        SQL
      else
        binds = [
          account_id,
          SAMPLE_ACCOUNTS_SIZE,
          ActiveRecord::Relation::QueryAttribute.new('group_keys', group_keys, ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::String.new)),
        ]

        ActiveRecord::Base.connection.select_all(<<~SQL.squish, 'grouped_notifications', binds).cast_values.to_h { |k, *values| [k, values] }
          SELECT
            groups.group_key,
            (SELECT id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key ORDER BY id DESC LIMIT 1),
            array(SELECT from_account_id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key ORDER BY id DESC LIMIT $2),
            (SELECT count(*) FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key) AS notifications_count,
            array(SELECT activity_id FROM notifications WHERE notifications.account_id = $1 AND notifications.group_key = groups.group_key AND activity_type = 'EmojiReaction')
          FROM
            unnest($3::text[]) AS groups(group_key);
        SQL
      end
    end
  end
end
