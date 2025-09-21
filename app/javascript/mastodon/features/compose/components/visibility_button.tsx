import { useCallback, useMemo } from 'react';
import type { FC } from 'react';

import { defineMessages, useIntl } from 'react-intl';

import classNames from 'classnames';

import {
  changeCircle,
  changeComposeSearchability,
  changeComposeVisibility,
} from '@/mastodon/actions/compose';
import { setComposeQuotePolicy } from '@/mastodon/actions/compose_typed';
import { openModal } from '@/mastodon/actions/modal';
import type { ApiQuotePolicy } from '@/mastodon/api_types/quotes';
import type {
  StatusSearchability,
  StatusVisibility,
} from '@/mastodon/api_types/statuses';
import { Icon } from '@/mastodon/components/icon';
import { useAppSelector, useAppDispatch } from '@/mastodon/store';
import { isFeatureEnabled } from '@/mastodon/utils/environment';
import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import BlockIcon from '@/material-icons/400-24px/block.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import MutualIcon from '@/material-icons/400-24px/compare_arrows.svg?react';
import LoginIcon from '@/material-icons/400-24px/key.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import QuietTimeIcon from '@/material-icons/400-24px/quiet_time.svg?react';
import ReplyIcon from '@/material-icons/400-24px/reply.svg?react';
import LimitedIcon from '@/material-icons/400-24px/shield.svg?react';
import PersonalIcon from '@/material-icons/400-24px/sticky_note.svg?react';

import type { VisibilityModalCallback } from '../../ui/components/visibility_modal';
import PrivacyDropdownContainer from '../containers/privacy_dropdown_container';

import { messages as privacyMessages } from './privacy_dropdown';
import { messages as searchabilityMessages } from './searchability_dropdown';

const messages = defineMessages({
  anyone_quote: {
    id: 'privacy.quote.anyone',
    defaultMessage: '{visibility}, anyone can quote',
  },
  limited_quote: {
    id: 'privacy.quote.limited',
    defaultMessage: '{visibility}, quotes limited',
  },
  disabled_quote: {
    id: 'privacy.quote.disabled',
    defaultMessage: '{visibility}, quotes disabled',
  },
});

interface PrivacyDropdownProps {
  disabled?: boolean;
}

export const VisibilityButton: FC<PrivacyDropdownProps> = (props) => {
  if (!isFeatureEnabled('outgoing_quotes')) {
    return <PrivacyDropdownContainer {...props} />;
  }
  return <PrivacyModalButton {...props} />;
};

const visibilityOptions = {
  public: {
    icon: 'globe',
    iconComponent: PublicIcon,
    value: 'public',
    text: privacyMessages.public_short,
  },
  unlisted: {
    icon: 'unlock',
    iconComponent: QuietTimeIcon,
    value: 'unlisted',
    text: privacyMessages.unlisted_short,
  },
  private: {
    icon: 'lock',
    iconComponent: LockIcon,
    value: 'private',
    text: privacyMessages.private_short,
  },
  direct: {
    icon: 'at',
    iconComponent: AlternateEmailIcon,
    value: 'direct',
    text: privacyMessages.direct_short,
  },
  public_unlisted: {
    icon: 'cloud',
    iconComponent: PublicUnlistedIcon,
    value: 'public_unlisted',
    text: privacyMessages.public_unlisted_short,
  },
  login: {
    icon: 'key',
    iconComponent: LoginIcon,
    value: 'login',
    text: privacyMessages.login_short,
  },
  mutual: {
    icon: 'exchange',
    iconComponent: MutualIcon,
    value: 'mutual',
    text: privacyMessages.mutual_short,
  },
  circle: {
    icon: 'user-circle',
    iconComponent: CircleIcon,
    value: 'circle',
    text: privacyMessages.circle_short,
  },
  reply: {
    icon: 'reply',
    iconComponent: ReplyIcon,
    value: 'reply',
    text: privacyMessages.reply_short,
  },
  limited: {
    icon: 'get-pocket',
    iconComponent: LimitedIcon,
    value: 'limited',
    text: privacyMessages.limited_short,
  },
  personal: {
    icon: 'sticky-note-o',
    iconComponent: PersonalIcon,
    value: 'personal',
    text: privacyMessages.personal_short,
  },
  banned: {
    icon: 'ban',
    iconComponent: BlockIcon,
    value: 'banned',
    text: privacyMessages.banned_short,
  },
};

const searchabilityOptions = {
  public: {
    value: 'public',
    text: searchabilityMessages.public_short,
  },
  public_unlisted: {
    value: 'public_unlisted',
    text: searchabilityMessages.public_unlisted_short,
  },
  direct: {
    value: 'direct',
    text: searchabilityMessages.direct_short,
  },
  private: {
    value: 'private',
    text: searchabilityMessages.private_short,
  },
  limited: {
    value: 'limited',
    text: searchabilityMessages.limited_short,
  },
};

const PrivacyModalButton: FC<PrivacyDropdownProps> = ({ disabled = false }) => {
  const intl = useIntl();

  const quotePolicy = useAppSelector(
    (state) => state.compose.get('quote_policy') as ApiQuotePolicy,
  );
  const visibility = useAppSelector(
    (state) => state.compose.get('privacy') as StatusVisibility,
  );
  const searchability = useAppSelector(
    (state) => state.compose.get('searchability') as StatusSearchability,
  );
  const circleId = useAppSelector(
    (state) => state.compose.get('circle_id') as string,
  );

  const { icon, iconComponent } = useMemo(() => {
    const option = visibilityOptions[visibility];
    return { icon: option.icon, iconComponent: option.iconComponent };
  }, [visibility]);
  const text = useMemo(() => {
    const visibilityText = [
      intl.formatMessage(visibilityOptions[visibility].text),
      intl.formatMessage(searchabilityOptions[searchability].text),
    ].join(', ');
    if (
      !['public', 'public_unlisted', 'unlisted', 'login'].includes(visibility)
    ) {
      return visibilityText;
    }
    if (quotePolicy === 'nobody') {
      return intl.formatMessage(messages.disabled_quote, {
        visibility: visibilityText,
      });
    }
    if (quotePolicy !== 'public') {
      return intl.formatMessage(messages.limited_quote, {
        visibility: visibilityText,
      });
    }
    return intl.formatMessage(messages.anyone_quote, {
      visibility: visibilityText,
    });
  }, [quotePolicy, visibility, searchability, intl]);

  const dispatch = useAppDispatch();

  const handleChange: VisibilityModalCallback = useCallback(
    (newVisibility, newSearchability, newQuotePolicy, newCircleId) => {
      if (newVisibility !== visibility) {
        dispatch(changeComposeVisibility(newVisibility));
      }
      if (newSearchability !== searchability) {
        dispatch(changeComposeSearchability(newSearchability));
      }
      if (newQuotePolicy !== quotePolicy) {
        dispatch(setComposeQuotePolicy(newQuotePolicy));
      }
      if (newCircleId !== circleId) {
        dispatch(changeCircle(newCircleId));
      }
    },
    [dispatch, quotePolicy, visibility, searchability, circleId],
  );

  const handleOpen = useCallback(() => {
    dispatch(
      openModal({
        modalType: 'COMPOSE_PRIVACY',
        modalProps: { onChange: handleChange },
      }),
    );
  }, [dispatch, handleChange]);

  return (
    <button
      type='button'
      title={intl.formatMessage(privacyMessages.change_privacy)}
      onClick={handleOpen}
      disabled={disabled}
      className={classNames('dropdown-button')}
    >
      <Icon id={icon} icon={iconComponent} />
      <span className='dropdown-button__label'>{text}</span>
    </button>
  );
};
