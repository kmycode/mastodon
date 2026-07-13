import type { FC, HTMLAttributes, MouseEventHandler, ReactNode } from 'react';

import { defineMessage, defineMessages, useIntl } from 'react-intl';

import classNames from 'classnames';
import { Link } from 'react-router-dom';

import type { Account, AccountShapeFull } from '@/mastodon/models/account';
import { selectAccountStatus } from '@/mastodon/selectors/statuses';
import { useAppSelector } from '@/mastodon/store';
import ReferenceIcon from '@/material-icons/400-24px/link.svg?react';
import LimitedIcon from '@/material-icons/400-24px/shield.svg?react';
import TimerIcon from '@/material-icons/400-24px/timer.svg?react';

import { Avatar } from '../avatar';
import { AvatarOverlay } from '../avatar_overlay';
import type { DisplayNameProps } from '../display_name';
import { LinkedDisplayName } from '../display_name';
import { Icon } from '../icon';
import { RelativeTimestamp } from '../relative_timestamp';
import { VisibilityIcon } from '../visibility_icon';

const messages = defineMessages({
  statusLimited: {
    id: 'status.limited',
    defaultMessage: 'Limited',
  },
  statusReference: {
    id: 'status.status_reference',
    defaultMessage: 'Link',
  },
  statusExpiration: {
    id: 'status.expiration',
    defaultMessage: 'Expiration',
  },
});

export interface StatusHeaderProps {
  statusId: string;
  account?: Account | AccountShapeFull;
  avatarSize?: number;
  contentBeforeDate?: ReactNode;
  contentAfterDate?: ReactNode;
  wrapperProps?: HTMLAttributes<HTMLDivElement>;
  displayNameProps?: DisplayNameProps;
  onHeaderClick?: MouseEventHandler<HTMLDivElement>;
  className?: string;
  featured?: boolean;
}

export type StatusHeaderRenderFn = (args: StatusHeaderProps) => ReactNode;

export const StatusHeader: FC<StatusHeaderProps> = ({
  statusId,
  account,
  className,
  avatarSize = 48,
  wrapperProps,
  contentBeforeDate,
  contentAfterDate,
  onHeaderClick,
}) => {
  const intl = useIntl();
  const status = useAppSelector((state) =>
    selectAccountStatus(state, statusId),
  );
  if (!status) {
    return null;
  }
  const statusAccount = status.account;
  const editedAt = status.edited_at;

  const hasLimitedLabel =
    status.visibility_ex === 'limited' && status.limited_scope !== 'none';

  const withLimited = hasLimitedLabel ? (
    <span
      className='status__visibility-icon'
      title={intl.formatMessage(messages.statusLimited)}
    >
      <Icon id='get-pocket' icon={LimitedIcon} />
    </span>
  ) : null;
  const withReference =
    status.status_references_count > 0 ? (
      <span
        className='status__visibility-icon'
        title={intl.formatMessage(messages.statusReference)}
      >
        <Icon id='link' icon={ReferenceIcon} />
      </span>
    ) : null;
  const withExpiration = status.expires_at ? (
    <span
      className='status__visibility-icon'
      title={intl.formatMessage(messages.statusExpiration)}
    >
      <Icon id='clock-o' icon={TimerIcon} />
    </span>
  ) : null;

  const displayVisibility = !hasLimitedLabel
    ? status.visibility_ex
    : status.limited_scope;

  return (
    /* eslint-disable jsx-a11y/no-static-element-interactions, jsx-a11y/click-events-have-key-events */
    <div
      onClick={onHeaderClick}
      onAuxClick={onHeaderClick}
      {...wrapperProps}
      className={classNames('status__info', className)}
      /* eslint-enable jsx-a11y/no-static-element-interactions, jsx-a11y/click-events-have-key-events */
    >
      <StatusDisplayName
        statusAccount={statusAccount}
        friendAccount={account}
        avatarSize={avatarSize}
      />

      {contentBeforeDate}

      <Link
        to={`/@${statusAccount.acct}/${status.id}`}
        className='status__relative-time'
      >
        {withReference}
        {withExpiration}
        {withLimited}
        <span className='status__visibility-icon'>
          <VisibilityIcon visibility={displayVisibility} />
        </span>
        <RelativeTimestamp timestamp={status.created_at} />
        {editedAt && <StatusEditedAt editedAt={editedAt} />}
      </Link>

      {contentAfterDate}
    </div>
  );
};

const editMessage = defineMessage({
  id: 'status.edited',
  defaultMessage: 'Edited {date}',
});

const StatusEditedAt: FC<{ editedAt: string }> = ({ editedAt }) => {
  const intl = useIntl();
  return (
    <abbr
      title={intl.formatMessage(editMessage, {
        date: intl.formatDate(editedAt, {
          year: 'numeric',
          month: 'short',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
        }),
      })}
    >
      {' '}
      *
    </abbr>
  );
};

const StatusDisplayName: FC<{
  statusAccount?: AccountShapeFull;
  friendAccount?: Account | AccountShapeFull;
  avatarSize: number;
}> = ({ statusAccount, friendAccount, avatarSize }) => {
  const AccountComponent = friendAccount ? AvatarOverlay : Avatar;
  return (
    <LinkedDisplayName
      displayProps={{ account: statusAccount }}
      className='status__display-name'
    >
      <div className='status__avatar'>
        <AccountComponent
          account={statusAccount}
          friend={friendAccount}
          size={avatarSize}
        />
      </div>
    </LinkedDisplayName>
  );
};
