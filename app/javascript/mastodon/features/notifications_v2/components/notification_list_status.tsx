import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import NotificationsActiveIcon from '@/material-icons/400-24px/notifications_active-fill.svg?react';
import type { NotificationGroupListStatus } from 'mastodon/models/notification_group';

import type { LabelRenderer } from './notification_group_with_status';
import { NotificationWithStatus } from './notification_with_status';

const createLabelRenderer = (
  notification: NotificationGroupListStatus,
): LabelRenderer => {
  const renderer: LabelRenderer = (values) => {
    const list = notification.list;
    if (list) {
      const listLink = (
        <bdi>
          <Link
            className='notification__display-name'
            href={`/lists/${list.id}`}
            title={list.title}
            to={`/lists/${list.id}`}
          >
            {list.title}
          </Link>
        </bdi>
      );
      values.listName = listLink;
    }

    return (
      <FormattedMessage
        id='notification.list_status'
        defaultMessage='{name} post is added to {listName}'
        values={values}
      />
    );
  };
  return renderer;
};

export const NotificationListStatus: React.FC<{
  notification: NotificationGroupListStatus;
  unread: boolean;
}> = ({ notification, unread }) => (
  <NotificationWithStatus
    type='list_status'
    icon={NotificationsActiveIcon}
    iconId='notifications-active'
    accountIds={notification.sampleAccountIds}
    count={notification.notifications_count}
    statusId={notification.statusId}
    labelRenderer={createLabelRenderer(notification)}
    unread={unread}
    muted
  />
);
