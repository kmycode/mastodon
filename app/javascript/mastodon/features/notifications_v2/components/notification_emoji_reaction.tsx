import { FormattedMessage } from 'react-intl';

import EmojiReactionIcon from '@/material-icons/400-24px/mood.svg?react';
import type { NotificationGroupEmojiReaction } from 'mastodon/models/notification_group';
import { useAppSelector } from 'mastodon/store';

import type { LabelRenderer } from './notification_group_with_status';
import { NotificationGroupWithStatus } from './notification_group_with_status';

const labelRenderer: LabelRenderer = (values) => (
  <FormattedMessage
    id='notification.emoji_reaction'
    defaultMessage='{name} reacted your status with emoji'
    values={values}
  />
);

export const NotificationEmojiReaction: React.FC<{
  notification: NotificationGroupEmojiReaction;
  unread: boolean;
}> = ({ notification, unread }) => {
  const { statusId } = notification;
  const statusAccount = useAppSelector(
    (state) =>
      state.accounts.get(state.statuses.getIn([statusId, 'account']) as string)
        ?.acct,
  );

  return (
    <NotificationGroupWithStatus
      type='emoji_reaction'
      icon={EmojiReactionIcon}
      iconId='star'
      accountIds={notification.sampleAccountIds}
      emojiReactionGroups={notification.emojiReactionGroups}
      statusId={notification.statusId}
      timestamp={notification.latest_page_notification_at}
      count={notification.notifications_count}
      labelRenderer={labelRenderer}
      labelSeeMoreHref={
        statusAccount
          ? `/@${statusAccount}/${statusId}/emoji_reactions`
          : undefined
      }
      unread={unread}
    />
  );
};
