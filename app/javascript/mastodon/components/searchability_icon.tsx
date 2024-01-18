import { defineMessages, useIntl } from 'react-intl';

import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import LockOpenIcon from '@/material-icons/400-24px/no_encryption.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';

import { Icon } from './icon';

type Searchability =
  | 'public'
  | 'public_unlisted'
  | 'private'
  | 'direct'
  | 'limited';

const messages = defineMessages({
  public_short: { id: 'searchability.public.short', defaultMessage: 'Public' },
  public_unlisted_short: {
    id: 'searchability.public_unlisted.short',
    defaultMessage: 'Public unlisted',
  },
  private_short: {
    id: 'searchability.unlisted.short',
    defaultMessage: 'Followers',
  },
  direct_short: {
    id: 'searchability.private.short',
    defaultMessage: 'Reactionners',
  },
  limited_short: {
    id: 'searchability.direct.short',
    defaultMessage: 'Self only',
  },
});

export const SearchabilityIcon: React.FC<{ searchability: Searchability }> = ({
  searchability,
}) => {
  const intl = useIntl();

  const searchabilityIconInfo = {
    public: {
      icon: 'globe',
      iconComponent: PublicIcon,
      text: intl.formatMessage(messages.public_short),
    },
    public_unlisted: {
      icon: 'cloud',
      iconComponent: PublicUnlistedIcon,
      text: intl.formatMessage(messages.public_unlisted_short),
    },
    private: {
      icon: 'lock',
      iconComponent: LockOpenIcon,
      text: intl.formatMessage(messages.private_short),
    },
    limited: {
      icon: 'get-pocket',
      iconComponent: AlternateEmailIcon,
      text: intl.formatMessage(messages.limited_short),
    },
    direct: {
      icon: 'at',
      iconComponent: LockIcon,
      text: intl.formatMessage(messages.direct_short),
    },
  };

  const searchabilityIcon = searchabilityIconInfo[searchability];

  return (
    <Icon
      id={searchabilityIcon.icon}
      icon={searchabilityIcon.iconComponent}
      title={searchabilityIcon.text}
    />
  );
};
