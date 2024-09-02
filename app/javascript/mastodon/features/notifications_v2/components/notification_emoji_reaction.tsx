import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import EmojiReactionIcon from '@/material-icons/400-24px/mood.svg?react';
import type { NotificationGroupEmojiReaction } from 'mastodon/models/notification_group';
import { useAppSelector } from 'mastodon/store';

import type { LabelRenderer } from './notification_group_with_status';
import { NotificationGroupWithStatus } from './notification_group_with_status';

const labelRenderer: LabelRenderer = (displayedName, total, seeMoreHref) => {
  if (total === 1)
    return (
      <FormattedMessage
        id='notification.emoji_reaction'
        defaultMessage='{name} reacted your post with emoji'
        values={{ name: displayedName }}
      />
    );

  return (
    <FormattedMessage
      id='notification.emoji_reaction.name_and_others_with_link'
      defaultMessage='{name} and <a>{count, plural, one {# other} other {# others}}</a> reacted your post with emoji'
      values={{
        name: displayedName,
        count: total - 1,
        a: (chunks) =>
          seeMoreHref ? <Link to={seeMoreHref}>{chunks}</Link> : chunks,
      }}
    />
  );
};

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
