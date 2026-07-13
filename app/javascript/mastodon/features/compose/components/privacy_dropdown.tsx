import { useCallback, useRef, useState } from 'react';

import { defineMessages, useIntl } from 'react-intl';

import classNames from 'classnames';

import type { StatusVisibility } from '@/mastodon/api_types/statuses';
import { Popover } from '@/mastodon/components/popover';
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
import { DropdownSelector } from 'mastodon/components/dropdown_selector';
import { Icon } from 'mastodon/components/icon';
import { enabledVisibilites } from 'mastodon/initial_state';

export const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_long: {
    id: 'privacy.public.long',
    defaultMessage: 'Anyone on and off Mastodon',
  },
  public_unlisted_short: {
    id: 'privacy.public_unlisted.short',
    defaultMessage: 'Local public',
  },
  public_unlisted_long: {
    id: 'privacy.public_unlisted.long',
    defaultMessage: 'Visible for all without GTL',
  },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  login_long: { id: 'privacy.login.long', defaultMessage: 'Login user only' },
  unlisted_short: {
    id: 'privacy.unlisted.short',
    defaultMessage: 'Quiet public',
  },
  unlisted_long: {
    id: 'privacy.unlisted.long',
    defaultMessage:
      'Hidden from Mastodon search results, trending, and public timelines',
  },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers' },
  private_long: {
    id: 'privacy.private.long',
    defaultMessage: 'Only your followers',
  },
  limited_short: { id: 'privacy.limited.short', defaultMessage: 'Limited' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual' },
  mutual_long: {
    id: 'privacy.mutual.long',
    defaultMessage: 'Mutual follows only',
  },
  personal_short: {
    id: 'privacy.personal.short',
    defaultMessage: 'Yourself only',
  },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle' },
  circle_long: {
    id: 'privacy.circle.long',
    defaultMessage: 'Circle members only',
  },
  reply_short: { id: 'privacy.reply.short', defaultMessage: 'Reply' },
  reply_long: {
    id: 'privacy.reply.long',
    defaultMessage: 'Reply to limited post',
  },
  direct_short: {
    id: 'privacy.direct.short',
    defaultMessage: 'Specific people',
  },
  direct_long: {
    id: 'privacy.direct.long',
    defaultMessage: 'Everyone mentioned in the post',
  },
  banned_short: { id: 'privacy.banned.short', defaultMessage: 'No posting' },
  banned_long: {
    id: 'privacy.banned.long',
    defaultMessage:
      'All public range submissions are disabled. User settings need to be modified.',
  },
  change_privacy: {
    id: 'privacy.change',
    defaultMessage: 'Change post privacy',
  },
  unlisted_extra: {
    id: 'privacy.unlisted.additional',
    defaultMessage:
      'This behaves exactly like public, except the post will not appear in live feeds or hashtags, explore, or Mastodon search, even if you are opted-in account-wide.',
  },
});

interface PrivacyDropdownProps {
  value: StatusVisibility;
  onChange: (value: StatusVisibility) => void;
  noDirect?: boolean;
  disabled?: boolean;
  noLimited?: boolean;
  replyToLimited?: boolean;
}

const PrivacyDropdown: React.FC<PrivacyDropdownProps> = ({
  value,
  onChange,
  noDirect,
  disabled,
  noLimited,
  replyToLimited,
}) => {
  const intl = useIntl();
  const [popoverTarget, setPopoverTarget] = useState<HTMLDivElement | null>(
    null,
  );
  const previousFocusTargetRef = useRef<HTMLElement>(null);
  const [isOpen, setIsOpen] = useState(false);

  const handleClose = useCallback(() => {
    if (isOpen && previousFocusTargetRef.current) {
      previousFocusTargetRef.current.focus({ preventScroll: true });
    }
    setIsOpen(false);
  }, [isOpen]);

  const handleToggle = useCallback(() => {
    if (isOpen) {
      handleClose();
    }
    setIsOpen((prev) => !prev);
  }, [handleClose, isOpen]);

  const registerPreviousFocusTarget = useCallback(() => {
    if (!isOpen) {
      previousFocusTargetRef.current = document.activeElement as HTMLElement;
    }
  }, [isOpen]);

  const handleButtonKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if ([' ', 'Enter'].includes(e.key)) {
        registerPreviousFocusTarget();
      }
    },
    [registerPreviousFocusTarget],
  );

  let options = [
    {
      icon: 'globe',
      iconComponent: PublicIcon,
      value: 'public',
      text: intl.formatMessage(messages.public_short),
      meta: intl.formatMessage(messages.public_long),
    },
    {
      icon: 'cloud',
      iconComponent: PublicUnlistedIcon,
      value: 'public_unlisted',
      text: intl.formatMessage(messages.public_unlisted_short),
      meta: intl.formatMessage(messages.public_unlisted_long),
    },
    {
      icon: 'key',
      iconComponent: LoginIcon,
      value: 'login',
      text: intl.formatMessage(messages.login_short),
      meta: intl.formatMessage(messages.login_long),
    },
    {
      icon: 'unlock',
      iconComponent: QuietTimeIcon,
      value: 'unlisted',
      text: intl.formatMessage(messages.unlisted_short),
      meta: intl.formatMessage(messages.unlisted_long),
      extra: intl.formatMessage(messages.unlisted_extra),
    },
    {
      icon: 'lock',
      iconComponent: LockIcon,
      value: 'private',
      text: intl.formatMessage(messages.private_short),
      meta: intl.formatMessage(messages.private_long),
    },
    {
      icon: 'exchange',
      iconComponent: MutualIcon,
      value: 'mutual',
      text: intl.formatMessage(messages.mutual_short),
      meta: intl.formatMessage(messages.mutual_long),
      extra: intl.formatMessage(messages.limited_short),
      extraIconComponent: LimitedIcon,
    },
    {
      icon: 'user-circle',
      iconComponent: CircleIcon,
      value: 'circle',
      text: intl.formatMessage(messages.circle_short),
      meta: intl.formatMessage(messages.circle_long),
      extra: intl.formatMessage(messages.limited_short),
      extraIconComponent: LimitedIcon,
    },
  ];

  if (!noDirect) {
    options.push({
      icon: 'at',
      iconComponent: AlternateEmailIcon,
      value: 'direct',
      text: intl.formatMessage(messages.direct_short),
      meta: intl.formatMessage(messages.direct_long),
    });
  }

  if (replyToLimited) {
    options.unshift({
      icon: 'reply',
      iconComponent: ReplyIcon,
      value: 'reply',
      text: intl.formatMessage(messages.reply_short),
      meta: intl.formatMessage(messages.reply_long),
      extra: intl.formatMessage(messages.limited_short),
      extraIconComponent: LimitedIcon,
    });
  }

  if (noLimited) {
    options = options.filter(
      (opt) => !['mutual', 'circle'].includes(opt.value),
    );
  }

  if (enabledVisibilites) {
    // @ts-expect-error - vsc errors this code, but enabledVisibilities is not null/undefined
    options = options.filter((opt) => enabledVisibilites.includes(opt.value));
  }

  if (options.length === 0) {
    options.push({
      icon: 'ban',
      iconComponent: BlockIcon,
      value: 'banned',
      text: intl.formatMessage(messages.banned_short),
      meta: intl.formatMessage(messages.banned_long),
    });
  }

  const selectedOption =
    options.find((item) => item.value === value || 'reply' === value) ??
    options.at(0);

  return (
    <div ref={setPopoverTarget}>
      <button
        type='button'
        title={intl.formatMessage(messages.change_privacy)}
        aria-expanded={isOpen}
        onClick={handleToggle}
        onMouseDown={registerPreviousFocusTarget}
        onKeyDown={handleButtonKeyDown}
        disabled={disabled}
        className={classNames('dropdown-button', { active: isOpen })}
      >
        {selectedOption && (
          <>
            <Icon
              id={selectedOption.icon}
              icon={selectedOption.iconComponent}
            />
            <span className='dropdown-button__label'>
              {selectedOption.text}
            </span>
          </>
        )}
      </button>

      <Popover
        isOpen={isOpen}
        offset={5}
        reference={popoverTarget}
        onClose={handleClose}
      >
        {({ props, placement }) => (
          <div {...props}>
            <div
              className={`dropdown-animation privacy-dropdown__dropdown ${placement}`}
            >
              <DropdownSelector
                items={options}
                value={value}
                onClose={handleClose}
                // @ts-expect-error DropdownSelector doesn't yet return the correct type for onChange
                onChange={onChange}
              />
            </div>
          </div>
        )}
      </Popover>
    </div>
  );
};

// eslint-disable-next-line import/no-default-export
export default PrivacyDropdown;
