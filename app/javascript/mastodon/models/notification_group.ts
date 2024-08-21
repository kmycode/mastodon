import type {
  ApiAccountRelationshipSeveranceEventJSON,
  ApiAccountWarningJSON,
  BaseNotificationGroupJSON,
  ApiNotificationGroupJSON,
  ApiNotificationJSON,
  NotificationType,
  NotificationWithStatusType,
  NotificationEmojiReactionGroupJSON,
  NotifyEmojiReactionJSON,
} from 'mastodon/api_types/notifications';
import type { ApiReportJSON } from 'mastodon/api_types/reports';

// Maximum number of avatars displayed in a notification group
// This corresponds to the max lenght of `group.sampleAccountIds`
export const NOTIFICATIONS_GROUP_MAX_AVATARS = 8;

interface BaseNotificationGroup
  extends Omit<BaseNotificationGroupJSON, 'sample_account_ids'> {
  sampleAccountIds: string[];
}

interface BaseNotificationWithStatus<Type extends NotificationWithStatusType>
  extends BaseNotificationGroup {
  type: Type;
  statusId: string | undefined;
  emojiReactionGroups?: EmojiReactionGroup[];
}

interface EmojiInfo {
  name: string;
  count: number;
  me: boolean;
  url?: string;
  static_url?: string;
  domain?: string;
  width?: number;
  height?: number;
}

export interface EmojiReactionGroup {
  emoji: EmojiInfo;
  sampleAccountIds: string[];
}

interface BaseNotification<Type extends NotificationType>
  extends BaseNotificationGroup {
  type: Type;
}

export type NotificationGroupFavourite =
  BaseNotificationWithStatus<'favourite'>;
export type NotificationGroupEmojiReaction =
  BaseNotificationWithStatus<'emoji_reaction'>;
export type NotificationGroupReblog = BaseNotificationWithStatus<'reblog'>;
export type NotificationGroupStatus = BaseNotificationWithStatus<'status'>;
export type NotificationGroupListStatus =
  BaseNotificationWithStatus<'list_status'>;
export type NotificationGroupMention = BaseNotificationWithStatus<'mention'>;
export type NotificationGroupStatusReference =
  BaseNotificationWithStatus<'status_reference'>;
export type NotificationGroupPoll = BaseNotificationWithStatus<'poll'>;
export type NotificationGroupUpdate = BaseNotificationWithStatus<'update'>;
export type NotificationGroupFollow = BaseNotification<'follow'>;
export type NotificationGroupFollowRequest = BaseNotification<'follow_request'>;
export type NotificationGroupAdminSignUp = BaseNotification<'admin.sign_up'>;

export type AccountWarningAction =
  | 'none'
  | 'disable'
  | 'force_cw'
  | 'mark_statuses_as_sensitive'
  | 'delete_statuses'
  | 'sensitive'
  | 'silence'
  | 'suspend';
export interface AccountWarning
  extends Omit<ApiAccountWarningJSON, 'target_account'> {
  targetAccountId: string;
}

export interface NotificationGroupModerationWarning
  extends BaseNotification<'moderation_warning'> {
  moderationWarning: AccountWarning;
}

type AccountRelationshipSeveranceEvent =
  ApiAccountRelationshipSeveranceEventJSON;
export interface NotificationGroupSeveredRelationships
  extends BaseNotification<'severed_relationships'> {
  event: AccountRelationshipSeveranceEvent;
}

interface Report extends Omit<ApiReportJSON, 'target_account'> {
  targetAccountId: string;
}

export interface NotificationGroupAdminReport
  extends BaseNotification<'admin.report'> {
  report: Report;
}

export type NotificationGroup =
  | NotificationGroupFavourite
  | NotificationGroupEmojiReaction
  | NotificationGroupReblog
  | NotificationGroupStatus
  | NotificationGroupListStatus
  | NotificationGroupMention
  | NotificationGroupStatusReference
  | NotificationGroupPoll
  | NotificationGroupUpdate
  | NotificationGroupFollow
  | NotificationGroupFollowRequest
  | NotificationGroupModerationWarning
  | NotificationGroupSeveredRelationships
  | NotificationGroupAdminSignUp
  | NotificationGroupAdminReport;

function createReportFromJSON(reportJSON: ApiReportJSON): Report {
  const { target_account, ...report } = reportJSON;
  return {
    targetAccountId: target_account.id,
    ...report,
  };
}

function createAccountWarningFromJSON(
  warningJSON: ApiAccountWarningJSON,
): AccountWarning {
  const { target_account, ...warning } = warningJSON;
  return {
    targetAccountId: target_account.id,
    ...warning,
  };
}

function createAccountRelationshipSeveranceEventFromJSON(
  eventJson: ApiAccountRelationshipSeveranceEventJSON,
): AccountRelationshipSeveranceEvent {
  return eventJson;
}

function createEmojiReactionGroupsFromJSON(
  json: NotifyEmojiReactionJSON | undefined,
  sampleAccountIds: string[],
): EmojiReactionGroup[] {
  if (typeof json === 'undefined') return [];

  return [
    {
      emoji: json,
      sampleAccountIds,
    },
  ];
}

export function createNotificationGroupFromJSON(
  groupJson: ApiNotificationGroupJSON,
): NotificationGroup {
  const { sample_account_ids: sampleAccountIds, ...group } = groupJson;

  switch (group.type) {
    case 'favourite':
    case 'reblog':
    case 'status':
    case 'list_status':
    case 'mention':
    case 'status_reference':
    case 'poll':
    case 'update': {
      const { status_id: statusId, ...groupWithoutStatus } = group;
      return {
        statusId: statusId ?? undefined,
        sampleAccountIds,
        ...groupWithoutStatus,
      };
    }
    case 'emoji_reaction': {
      const {
        status_id: statusId,
        emoji_reaction_groups: emojiReactionGroups,
        ...groupWithoutStatus
      } = group;
      const groups = (
        typeof emojiReactionGroups === 'undefined'
          ? ([] as NotificationEmojiReactionGroupJSON[])
          : emojiReactionGroups
      ).map((g) => {
        return {
          sampleAccountIds: g.sample_account_ids,
          emoji: g.emoji_reaction,
        } as EmojiReactionGroup;
      });
      return {
        statusId: statusId ?? undefined,
        sampleAccountIds,
        emojiReactionGroups: groups,
        ...groupWithoutStatus,
      };
    }
    case 'admin.report': {
      const { report, ...groupWithoutTargetAccount } = group;
      return {
        report: createReportFromJSON(report),
        sampleAccountIds,
        ...groupWithoutTargetAccount,
      };
    }
    case 'severed_relationships':
      return {
        ...group,
        event: createAccountRelationshipSeveranceEventFromJSON(group.event),
        sampleAccountIds,
      };

    case 'moderation_warning': {
      const { moderation_warning, ...groupWithoutModerationWarning } = group;
      return {
        ...groupWithoutModerationWarning,
        moderationWarning: createAccountWarningFromJSON(moderation_warning),
        sampleAccountIds,
      };
    }
    default:
      return {
        sampleAccountIds,
        ...group,
      };
  }
}

export function createNotificationGroupFromNotificationJSON(
  notification: ApiNotificationJSON,
) {
  const group = {
    sampleAccountIds: [notification.account.id],
    group_key: notification.group_key,
    notifications_count: 1,
    type: notification.type,
    most_recent_notification_id: notification.id,
    page_min_id: notification.id,
    page_max_id: notification.id,
    latest_page_notification_at: notification.created_at,
  } as NotificationGroup;

  switch (notification.type) {
    case 'favourite':
    case 'reblog':
    case 'status':
    case 'mention':
    case 'status_reference':
    case 'poll':
    case 'update':
      return { ...group, statusId: notification.status?.id };
    case 'list_status':
      return {
        ...group,
        statusId: notification.status?.id,
        list: notification.list,
      };
    case 'emoji_reaction':
      return {
        ...group,
        statusId: notification.status?.id,
        emojiReactionGroups: createEmojiReactionGroupsFromJSON(
          notification.emoji_reaction,
          group.sampleAccountIds,
        ),
      };
    case 'admin.report':
      return { ...group, report: createReportFromJSON(notification.report) };
    case 'severed_relationships':
      return {
        ...group,
        event: createAccountRelationshipSeveranceEventFromJSON(
          notification.event,
        ),
      };
    case 'moderation_warning':
      return {
        ...group,
        moderationWarning: createAccountWarningFromJSON(
          notification.moderation_warning,
        ),
      };
    default:
      return group;
  }
}
