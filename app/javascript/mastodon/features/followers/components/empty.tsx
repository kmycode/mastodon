import type { FC, ReactNode } from 'react';

import { FormattedMessage } from 'react-intl';

import { LimitedAccountHint } from '@/mastodon/components/limited_account_hint';
import { useAccountVisibility } from '@/mastodon/hooks/useAccountVisibility';
import { isHideItem, me } from '@/mastodon/initial_state';
import type { Account } from '@/mastodon/models/account';

import { RemoteHint } from './remote';

interface BaseEmptyMessageProps {
  account?: Account;
  defaultMessage: ReactNode;
}
export type EmptyMessageProps = Omit<BaseEmptyMessageProps, 'defaultMessage'>;

export const BaseEmptyMessage: FC<BaseEmptyMessageProps> = ({
  account,
  defaultMessage,
}) => {
  const { blockedBy, hidden, suspended } = useAccountVisibility(account?.id);
  const isHideRelationships = isHideItem('relationships') && account?.id === me;

  if (!account) {
    return null;
  }

  if (suspended) {
    return (
      <FormattedMessage
        id='empty_column.account_suspended'
        defaultMessage='Account suspended'
      />
    );
  }

  if (hidden) {
    return <LimitedAccountHint accountId={account.id} />;
  }

  if (blockedBy) {
    return (
      <FormattedMessage
        id='empty_column.account_unavailable'
        defaultMessage='Profile unavailable'
      />
    );
  }

  if (account.hide_collections) {
    return (
      <FormattedMessage
        id='empty_column.account_hides_collections'
        defaultMessage='This user has chosen to not make this information available'
      />
    );
  }

  if (isHideRelationships) {
    return (
      <FormattedMessage
        id='account.followers.hidden_from_me'
        defaultMessage='This information is hidden by your setting.'
      />
    );
  }

  const domain = account.acct.split('@')[1];
  if (domain) {
    return <RemoteHint domain={domain} url={account.url} />;
  }

  return defaultMessage;
};
