import { defineMessages, useIntl } from 'react-intl';

import { ReactComponent as CircleIcon } from '@material-symbols/svg-600/outlined/account_circle.svg';
import { ReactComponent as AlternateEmailIcon } from '@material-symbols/svg-600/outlined/alternate_email.svg';
import { ReactComponent as PublicUnlistedIcon } from '@material-symbols/svg-600/outlined/cloud.svg';
import { ReactComponent as MutualIcon } from '@material-symbols/svg-600/outlined/compare_arrows.svg';
import { ReactComponent as LoginIcon } from '@material-symbols/svg-600/outlined/key.svg';
import { ReactComponent as LockIcon } from '@material-symbols/svg-600/outlined/lock.svg';
import { ReactComponent as LockOpenIcon } from '@material-symbols/svg-600/outlined/no_encryption.svg';
import { ReactComponent as PublicIcon } from '@material-symbols/svg-600/outlined/public.svg';
import { ReactComponent as ReplyIcon } from '@material-symbols/svg-600/outlined/reply.svg';
import { ReactComponent as LimitedIcon } from '@material-symbols/svg-600/outlined/shield.svg';
import { ReactComponent as PersonalIcon } from '@material-symbols/svg-600/outlined/sticky_note.svg';

import { Icon } from './icon';

type Visibility =
  | 'public'
  | 'unlisted'
  | 'private'
  | 'direct'
  | 'public_unlisted'
  | 'login'
  | 'mutual'
  | 'circle'
  | 'personal'
  | 'reply'
  | 'limited';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_unlisted_short: {
    id: 'privacy.public_unlisted.short',
    defaultMessage: 'Public unlisted',
  },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Unlisted' },
  private_short: {
    id: 'privacy.private.short',
    defaultMessage: 'Followers only',
  },
  limited_short: {
    id: 'privacy.limited.short',
    defaultMessage: 'Limited menbers only',
  },
  mutual_short: {
    id: 'privacy.mutual.short',
    defaultMessage: 'Mutual followers only',
  },
  circle_short: {
    id: 'privacy.circle.short',
    defaultMessage: 'Circle members only',
  },
  reply_short: {
    id: 'privacy.reply.short',
    defaultMessage: 'Reply',
  },
  personal_short: {
    id: 'privacy.personal.short',
    defaultMessage: 'Yourself only',
  },
  direct_short: {
    id: 'privacy.direct.short',
    defaultMessage: 'Mentioned people only',
  },
});

export const VisibilityIcon: React.FC<{ visibility: Visibility }> = ({
  visibility,
}) => {
  const intl = useIntl();

  const visibilityIconInfo = {
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
    login: {
      icon: 'key',
      iconComponent: LoginIcon,
      text: intl.formatMessage(messages.login_short),
    },
    unlisted: {
      icon: 'unlock',
      iconComponent: LockOpenIcon,
      text: intl.formatMessage(messages.unlisted_short),
    },
    private: {
      icon: 'lock',
      iconComponent: LockIcon,
      text: intl.formatMessage(messages.private_short),
    },
    limited: {
      icon: 'get-pocket',
      iconComponent: LimitedIcon,
      text: intl.formatMessage(messages.limited_short),
    },
    mutual: {
      icon: 'exchange',
      iconComponent: MutualIcon,
      text: intl.formatMessage(messages.mutual_short),
    },
    circle: {
      icon: 'user-circle',
      iconComponent: CircleIcon,
      text: intl.formatMessage(messages.circle_short),
    },
    reply: {
      icon: 'reply',
      iconComponent: ReplyIcon,
      text: intl.formatMessage(messages.reply_short),
    },
    personal: {
      icon: 'sticky-note-o',
      iconComponent: PersonalIcon,
      text: intl.formatMessage(messages.personal_short),
    },
    direct: {
      icon: 'at',
      iconComponent: AlternateEmailIcon,
      text: intl.formatMessage(messages.direct_short),
    },
  };

  const visibilityIcon = visibilityIconInfo[visibility];

  return (
    <Icon
      id={visibilityIcon.icon}
      icon={visibilityIcon.iconComponent}
      title={visibilityIcon.text}
    />
  );
};
