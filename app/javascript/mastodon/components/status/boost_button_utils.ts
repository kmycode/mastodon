import { defineMessages } from 'react-intl';
import type { MessageDescriptor } from 'react-intl';

import { isHideItem } from '@/mastodon/initial_state';
import type { StatusConditions } from '@/mastodon/selectors/statuses';
import FormatQuote from '@/material-icons/400-24px/format_quote-fill.svg?react';
import FormatQuoteOff from '@/material-icons/400-24px/format_quote_off-fill.svg?react';
import ReferenceIcon from '@/material-icons/400-24px/link.svg?react';
import RepeatIcon from '@/material-icons/400-24px/repeat.svg?react';
import RepeatActiveIcon from '@/svg-icons/repeat_active.svg?react';
import RepeatDisabledIcon from '@/svg-icons/repeat_disabled.svg?react';
import RepeatPrivateIcon from '@/svg-icons/repeat_private.svg?react';
import RepeatPrivateActiveIcon from '@/svg-icons/repeat_private_active.svg?react';

import type { IconProp } from '../icon';

export const messages = defineMessages({
  all_disabled: {
    id: 'status.all_disabled',
    defaultMessage: 'Boosts and quotes are disabled',
  },
  quote: {
    id: 'status.quote',
    defaultMessage: 'Quote',
    description: 'Quote as a verb (e.g. Quote this post)',
  },
  quote_cannot: {
    id: 'status.cannot_quote',
    defaultMessage: 'You are not allowed to quote this post',
  },
  quote_followers_only: {
    id: 'status.quote_followers_only',
    defaultMessage: 'Only followers can quote this post',
  },
  quote_manual_review: {
    id: 'status.quote_manual_review',
    defaultMessage: 'Author will manually review',
  },
  quote_private: {
    id: 'status.quote_private',
    defaultMessage: 'Private posts cannot be quoted',
  },
  reblog: { id: 'status.reblog', defaultMessage: 'Boost' },
  reblog_or_quote: {
    id: 'status.reblog_or_quote',
    defaultMessage: 'Boost or quote',
  },
  reblog_cancel: {
    id: 'status.cancel_reblog_private',
    defaultMessage: 'Unboost',
  },
  reblog_private: {
    id: 'status.reblog_private',
    defaultMessage: 'Share again with your followers',
  },
  reblog_cannot: {
    id: 'status.cannot_reblog',
    defaultMessage: 'This post cannot be boosted',
  },
  request_quote: {
    id: 'status.request_quote',
    defaultMessage: 'Request to quote',
  },
  reblog_with_detail: {
    id: 'status.reblog_with_detail',
    defaultMessage: 'Boost with visibility',
  },
  reference_link: {
    id: 'status.reference_link',
    defaultMessage: 'Insert post link',
  },
  reference_disabled: {
    id: 'status.cannot_reference',
    defaultMessage: 'This server cannot receive link',
  },
  quote_link: { id: 'status.quote_link', defaultMessage: 'Insert quote link' },
});

export interface MenuItemState {
  title: MessageDescriptor;
  meta?: MessageDescriptor;
  iconComponent: IconProp;
  disabled?: boolean;
}

export function boostItemState(
  { isPublic, isPrivateReblog, isBoosted }: StatusConditions,
  isForceModal = false,
): MenuItemState {
  if (isBoosted) {
    return {
      title: messages.reblog_cancel,
      iconComponent: isPublic ? RepeatActiveIcon : RepeatPrivateActiveIcon,
    };
  }
  const iconText: MenuItemState = {
    title: isForceModal ? messages.reblog_with_detail : messages.reblog,
    iconComponent: RepeatIcon,
  };

  if (isPrivateReblog) {
    iconText.meta = messages.reblog_private;
    iconText.iconComponent = RepeatPrivateIcon;
  } else if (!isPublic) {
    iconText.meta = messages.reblog_cannot;
    iconText.iconComponent = RepeatDisabledIcon;
    iconText.disabled = true;
  }
  return iconText;
}

export function quoteItemState(
  {
    isLoggedIn,
    isMine,
    isQuoteAutomaticallyAccepted,
    isQuoteManuallyAccepted,
    isQuoteFollowersOnly,
    isPublic,
  }: StatusConditions,
  isLink = false,
): MenuItemState {
  const iconText: MenuItemState = {
    title: messages.quote,
    iconComponent: FormatQuote,
  };

  if (!isPublic && !isMine) {
    iconText.disabled = true;
    iconText.iconComponent = FormatQuoteOff;
    iconText.meta = messages.quote_private;
  } else if (isQuoteAutomaticallyAccepted) {
    iconText.title = messages.quote;
  } else if (isQuoteManuallyAccepted) {
    iconText.title = messages.request_quote;
    iconText.meta = messages.quote_manual_review;
    // We don't show the disabled state when logged out
  } else if (isLoggedIn) {
    iconText.disabled = true;
    iconText.iconComponent = FormatQuoteOff;
    iconText.meta = isQuoteFollowersOnly
      ? messages.quote_followers_only
      : messages.quote_cannot;
  }

  if (isLink) {
    iconText.title = messages.quote_link;
  }

  return iconText;
}

export function referenceItemState({
  isPublic,
  isStatusReferenceAvailableServer,
}: StatusConditions): MenuItemState {
  const iconText: MenuItemState = {
    title: messages.reference_link,
    iconComponent: ReferenceIcon,
  };

  if (!isPublic) {
    iconText.disabled = true;
  } else if (
    isHideItem('status_reference_unavailable_server') &&
    !isStatusReferenceAvailableServer
  ) {
    iconText.disabled = true;
    iconText.meta = messages.reference_disabled;
  }

  return iconText;
}
