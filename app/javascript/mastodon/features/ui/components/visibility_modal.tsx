import {
  forwardRef,
  useCallback,
  useId,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { FC } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import classNames from 'classnames';

import type { ApiQuotePolicy } from '@/mastodon/api_types/quotes';
import { isQuotePolicy } from '@/mastodon/api_types/quotes';
import {
  isStatusSearchability,
  isStatusVisibility,
} from '@/mastodon/api_types/statuses';
import type {
  StatusSearchability,
  StatusVisibility,
} from '@/mastodon/api_types/statuses';
import { Button } from '@/mastodon/components/button';
import { Dropdown } from '@/mastodon/components/dropdown';
import type { SelectItem } from '@/mastodon/components/dropdown_selector';
import { IconButton } from '@/mastodon/components/icon_button';
import { messages as privacyMessages } from '@/mastodon/features/compose/components/privacy_dropdown';
import { enabledVisibilites } from '@/mastodon/initial_state';
import { isUserTouching } from '@/mastodon/is_mobile';
import { createAppSelector, useAppSelector } from '@/mastodon/store';
import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import BlockIcon from '@/material-icons/400-24px/block.svg?react';
import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import MutualIcon from '@/material-icons/400-24px/compare_arrows.svg?react';
import LoginIcon from '@/material-icons/400-24px/key.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import LockOpenIcon from '@/material-icons/400-24px/no_encryption.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import QuietTimeIcon from '@/material-icons/400-24px/quiet_time.svg?react';
import ReplyIcon from '@/material-icons/400-24px/reply.svg?react';

import type { BaseConfirmationModalProps } from './confirmation_modals/confirmation_modal';

const searchabilityMessages = defineMessages({
  public_short: { id: 'searchability.public.short', defaultMessage: 'Public' },
  public_long: {
    id: 'searchability.public.long',
    defaultMessage: 'Anyone can find',
  },
  public_unlisted_short: {
    id: 'searchability.public_unlisted.short',
    defaultMessage: 'Local public',
  },
  public_unlisted_long: {
    id: 'searchability.public_unlisted.long',
    defaultMessage: 'Local users and followers can find',
  },
  private_short: {
    id: 'searchability.unlisted.short',
    defaultMessage: 'Followers',
  },
  private_long: {
    id: 'searchability.unlisted.long',
    defaultMessage: 'Your followers can find',
  },
  direct_short: {
    id: 'searchability.private.short',
    defaultMessage: 'Reactionners',
  },
  direct_long: {
    id: 'searchability.private.long',
    defaultMessage: 'Reacter of this post can find',
  },
  limited_short: {
    id: 'searchability.direct.short',
    defaultMessage: 'Self only',
  },
  limited_long: {
    id: 'searchability.direct.long',
    defaultMessage: 'Nobody can find, but you can',
  },
  change_searchability: {
    id: 'searchability.change',
    defaultMessage: 'Set status searchability',
  },
});

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
  buttonTitle: {
    id: 'visibility_modal.button_title',
    defaultMessage: 'Set visibility',
  },
  quotePublic: {
    id: 'visibility_modal.quote_public',
    defaultMessage: 'Anyone',
  },
  quoteFollowers: {
    id: 'visibility_modal.quote_followers',
    defaultMessage: 'Followers only',
  },
  quoteNobody: {
    id: 'visibility_modal.quote_nobody',
    defaultMessage: 'Just me',
  },
});

export type VisibilityModalCallback = (
  visibility: StatusVisibility,
  searchability: StatusSearchability,
  quotePolicy: ApiQuotePolicy,
  circleId: string,
) => void;

interface VisibilityModalProps extends BaseConfirmationModalProps {
  statusId?: string;
  onChange: VisibilityModalCallback;
}

const selectStatusPolicy = createAppSelector(
  [
    (state) => state.statuses,
    (_state, statusId?: string) => statusId,
    (state) => state.compose.get('quote_policy') as ApiQuotePolicy,
  ],
  (statuses, statusId, composeQuotePolicy) => {
    if (!statusId) {
      return composeQuotePolicy;
    }
    const status = statuses.get(statusId);
    if (!status) {
      return 'public';
    }
    const policy =
      (status.getIn(['quote_approval', 'automatic', 0]) as string) || 'nobody';
    const visibility = status.get('visibility') as StatusVisibility;

    // If the status is private or direct, it cannot be quoted by anyone.
    if (visibility === 'private' || visibility === 'direct') {
      return 'nobody';
    }

    // If the status has a specific quote policy, return it.
    if (isQuotePolicy(policy)) {
      return policy;
    }

    // Otherwise, return the default based on visibility.
    if (visibility === 'unlisted') {
      return 'followers';
    }
    return 'public';
  },
);

const selectDisablePublicVisibilities = createAppSelector(
  [
    (state) => state.statuses,
    (_state, statusId?: string) => !!statusId,
    (state) => state.compose.get('quoted_status_id') as string | null,
  ],
  (statuses, isEditing, statusId) => {
    if (isEditing || !statusId) return false;

    const status = statuses.get(statusId);
    if (!status) {
      return false;
    }

    return status.get('visibility') === 'private';
  },
);

export const VisibilityModal: FC<VisibilityModalProps> = forwardRef(
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  ({ onClose, onChange, statusId }, _ref) => {
    const intl = useIntl();
    const currentVisibility = useAppSelector((state) =>
      statusId
        ? ((state.statuses.getIn([statusId, 'visibility_ex'], 'public') as
            | StatusVisibility
            | undefined) ?? 'public')
        : (state.compose.get('privacy') as StatusVisibility),
    );
    const currentSearchability = useAppSelector((state) =>
      statusId
        ? ((state.statuses.getIn([statusId, 'searchability'], 'public') as
            | StatusSearchability
            | undefined) ?? 'public')
        : (state.compose.get('searchability') as StatusSearchability),
    );
    const currentQuotePolicy = useAppSelector((state) =>
      selectStatusPolicy(state, statusId),
    );
    const currentCircleId = useAppSelector(
      (state) => state.compose.get('circle_id') as string,
    );

    const replyToLimited = useAppSelector(
      (state) => state.compose.get('reply_to_limited') as boolean,
    );
    const circles = useAppSelector((state) =>
      state.circles
        .toList()
        .toArray()
        .filter((c) => c !== null),
    );

    const [visibility, setVisibility] = useState(currentVisibility);
    const [searchability, setSearchability] = useState(currentSearchability);
    const [quotePolicy, setQuotePolicy] = useState(currentQuotePolicy);
    const [circleId, setCircleId] = useState(currentCircleId);

    const disableVisibility = !!statusId;
    const disableQuotePolicy = [
      'private',
      'direct',
      'limited',
      'mutual',
      'circle',
    ].includes(visibility);
    const disablePublicVisibilities: boolean = useAppSelector(
      selectDisablePublicVisibilities,
    );
    const isQuotePost = useAppSelector(
      (state) => state.compose.get('quoted_status_id') !== null,
    );
    const disableSave = visibility === 'circle' && !circleId;

    const visibilityItems = useMemo<SelectItem<StatusVisibility>[]>(() => {
      const items: SelectItem<StatusVisibility>[] = [
        {
          value: 'private',
          text: intl.formatMessage(privacyMessages.private_short),
          meta: intl.formatMessage(privacyMessages.private_long),
          icon: 'lock',
          iconComponent: LockIcon,
        },
        {
          value: 'mutual',
          text: intl.formatMessage(privacyMessages.mutual_short),
          meta: intl.formatMessage(privacyMessages.mutual_long),
          icon: 'exchange',
          iconComponent: MutualIcon,
        },
        {
          value: 'circle',
          text: intl.formatMessage(privacyMessages.circle_short),
          meta: intl.formatMessage(privacyMessages.circle_long),
          icon: 'user-circle',
          iconComponent: CircleIcon,
        },
        {
          value: 'direct',
          text: intl.formatMessage(privacyMessages.direct_short),
          meta: intl.formatMessage(privacyMessages.direct_long),
          icon: 'at',
          iconComponent: AlternateEmailIcon,
        },
      ];

      const specialItems = {
        reply: {
          value: 'reply' as StatusVisibility,
          text: intl.formatMessage(privacyMessages.reply_short),
          meta: intl.formatMessage(privacyMessages.reply_long),
          icon: 'at',
          iconComponent: ReplyIcon,
        },
        banned: {
          value: 'banned' as StatusVisibility,
          text: intl.formatMessage(privacyMessages.banned_short),
          meta: intl.formatMessage(privacyMessages.banned_long),
          icon: 'ban',
          iconComponent: BlockIcon,
        },
      };

      if (!disablePublicVisibilities) {
        items.unshift(
          {
            value: 'public',
            text: intl.formatMessage(privacyMessages.public_short),
            meta: intl.formatMessage(privacyMessages.public_long),
            icon: 'globe',
            iconComponent: PublicIcon,
          },
          {
            value: 'public_unlisted',
            text: intl.formatMessage(privacyMessages.public_unlisted_short),
            meta: intl.formatMessage(privacyMessages.public_unlisted_long),
            icon: 'cloud',
            iconComponent: PublicUnlistedIcon,
          },
          {
            value: 'login',
            text: intl.formatMessage(privacyMessages.login_short),
            meta: intl.formatMessage(privacyMessages.login_long),
            icon: 'key',
            iconComponent: LoginIcon,
          },
          {
            value: 'unlisted',
            text: intl.formatMessage(privacyMessages.unlisted_short),
            meta: intl.formatMessage(privacyMessages.unlisted_long),
            icon: 'unlock',
            iconComponent: QuietTimeIcon,
          },
        );
      }

      if (replyToLimited) {
        items.unshift(specialItems.reply);
      }

      if (enabledVisibilites) {
        const filteredItems = items.filter((i) =>
          enabledVisibilites?.includes(i.value),
        );

        if (filteredItems.length === 0) {
          return [specialItems.banned];
        }

        return filteredItems;
      }

      return items;
    }, [intl, disablePublicVisibilities, replyToLimited]);
    const searchabilityItems = useMemo<SelectItem<StatusVisibility>[]>(() => {
      const items: SelectItem<StatusVisibility>[] = [
        {
          value: 'public',
          text: intl.formatMessage(searchabilityMessages.public_short),
          meta: intl.formatMessage(searchabilityMessages.public_long),
          icon: 'globe',
          iconComponent: PublicIcon,
        },
        {
          value: 'public_unlisted',
          text: intl.formatMessage(searchabilityMessages.public_unlisted_short),
          meta: intl.formatMessage(searchabilityMessages.public_unlisted_long),
          icon: 'cloud',
          iconComponent: PublicUnlistedIcon,
        },
        {
          value: 'private',
          text: intl.formatMessage(searchabilityMessages.private_short),
          meta: intl.formatMessage(searchabilityMessages.private_long),
          icon: 'lock',
          iconComponent: LockOpenIcon,
        },
        {
          value: 'direct',
          text: intl.formatMessage(searchabilityMessages.direct_short),
          meta: intl.formatMessage(searchabilityMessages.direct_long),
          icon: 'at',
          iconComponent: LockIcon,
        },
        {
          value: 'limited',
          text: intl.formatMessage(searchabilityMessages.limited_short),
          meta: intl.formatMessage(searchabilityMessages.limited_long),
          icon: 'at',
          iconComponent: AlternateEmailIcon,
        },
      ];
      return items;
    }, [intl]);
    const circleItems = useMemo<SelectItem[]>(() => {
      return circles.map((c) => {
        return {
          value: c.get('id'),
          text: c.get('title'),
        };
      });
    }, [circles]);
    const quoteItems = useMemo<SelectItem<ApiQuotePolicy>[]>(
      () => [
        { value: 'public', text: intl.formatMessage(messages.quotePublic) },
        {
          value: 'followers',
          text: intl.formatMessage(messages.quoteFollowers),
        },
        { value: 'nobody', text: intl.formatMessage(messages.quoteNobody) },
      ],
      [intl],
    );

    const handleVisibilityChange = useCallback((value: string) => {
      if (isStatusVisibility(value)) {
        setVisibility(value);
      }
    }, []);
    const handleSearchabilityChange = useCallback((value: string) => {
      if (isStatusSearchability(value)) {
        setSearchability(value);
      }
    }, []);
    const handleQuotePolicyChange = useCallback((value: string) => {
      if (isQuotePolicy(value)) {
        setQuotePolicy(value);
      }
    }, []);
    const handleCircleIdChange = useCallback(
      (value: string) => {
        if (circleItems.some((c) => c.value === value)) {
          setCircleId(value);
        } else {
          setCircleId('');
        }
      },
      [circleItems],
    );
    const handleSave = useCallback(() => {
      onChange(visibility, searchability, quotePolicy, circleId);
      onClose();
    }, [onChange, onClose, visibility, searchability, quotePolicy, circleId]);

    const uniqueId = useId();
    const visibilityLabelId = `${uniqueId}-visibility-label`;
    const visibilityDescriptionId = `${uniqueId}-visibility-desc`;
    const quoteLabelId = `${uniqueId}-quote-label`;
    const quoteDescriptionId = `${uniqueId}-quote-desc`;
    const searchabilityLabelId = `${uniqueId}-searchability-label`;
    const searchabilityDescriptionId = `${uniqueId}-searchability-desc`;
    const circleLabelId = `${uniqueId}-circle-label`;
    const circleDescriptionId = `${uniqueId}-circle-desc`;

    const saveRef = useRef<HTMLDivElement>(null);

    return (
      <div className='modal-root__modal dialog-modal visibility-modal'>
        <div className='dialog-modal__header'>
          <IconButton
            className='dialog-modal__header__close'
            title={intl.formatMessage(messages.close)}
            icon='times'
            iconComponent={CloseIcon}
            onClick={onClose}
          />
          <FormattedMessage
            id='visibility_modal.header'
            defaultMessage='Visibility and interaction'
          >
            {(chunks) => (
              <span className='dialog-modal__header__title'>{chunks}</span>
            )}
          </FormattedMessage>
        </div>
        <div className='dialog-modal__content'>
          <div className='dialog-modal__content__description'>
            <FormattedMessage
              id='visibility_modal.instructions'
              defaultMessage='Control who can interact with this post. You can also apply settings to all future posts by navigating to <link>Preferences > Posting defaults</link>.'
              values={{
                link: (chunks) => (
                  <a href='/settings/preferences/posting_defaults'>{chunks}</a>
                ),
              }}
              tagName='p'
            />
          </div>
          <div className='dialog-modal__content__form'>
            <div
              className={classNames('visibility-dropdown', {
                disabled: disableVisibility,
              })}
            >
              {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
              <label
                className='visibility-dropdown__label'
                id={visibilityLabelId}
              >
                <FormattedMessage
                  id='visibility_modal.privacy_label'
                  defaultMessage='Visibility'
                />
              </label>

              <Dropdown
                items={visibilityItems}
                current={visibility}
                onChange={handleVisibilityChange}
                labelId={visibilityLabelId}
                descriptionId={visibilityDescriptionId}
                classPrefix='visibility-dropdown'
                disabled={disableVisibility}
                placement={isUserTouching() ? 'top' : 'bottom-start'}
                target={isUserTouching() ? saveRef : undefined}
              />
              {!!statusId && (
                <p
                  className='visibility-dropdown__helper'
                  id='visibilityDescriptionId'
                >
                  <FormattedMessage
                    id='visibility_modal.helper.privacy_editing'
                    defaultMessage="Visibility can't be changed after a post is published."
                  />
                </p>
              )}
              {!statusId && disablePublicVisibilities && (
                <p
                  className='visibility-dropdown__helper'
                  id='visibilityDescriptionId'
                >
                  <FormattedMessage
                    id='visibility_modal.helper.privacy_private_self_quote'
                    defaultMessage='Self-quotes of private posts cannot be made public.'
                  />
                </p>
              )}
            </div>

            {!statusId && visibility === 'circle' && (
              <div
                className={classNames('visibility-dropdown', {
                  disabled: disableVisibility,
                })}
              >
                {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
                <label
                  className='visibility-dropdown__label'
                  id={circleLabelId}
                >
                  <FormattedMessage
                    id='visibility_modal.circle_label'
                    defaultMessage='Circle'
                  />
                </label>

                <Dropdown
                  items={circleItems}
                  current={circleId}
                  onChange={handleCircleIdChange}
                  labelId={circleLabelId}
                  descriptionId={circleDescriptionId}
                  classPrefix='visibility-dropdown'
                  disabled={disableVisibility}
                />
              </div>
            )}

            <div
              className={classNames('visibility-dropdown', {
                disabled: disableVisibility,
              })}
            >
              {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
              <label
                className='visibility-dropdown__label'
                id={searchabilityLabelId}
              >
                <FormattedMessage
                  id='visibility_modal.searchability_label'
                  defaultMessage='Searchability'
                />
              </label>

              <Dropdown
                items={searchabilityItems}
                current={searchability}
                onChange={handleSearchabilityChange}
                labelId={searchabilityLabelId}
                descriptionId={searchabilityDescriptionId}
                classPrefix='visibility-dropdown'
                disabled={disableVisibility}
              />
              {!!statusId && (
                <p
                  className='visibility-dropdown__helper'
                  id='searchabilityDescriptionId'
                >
                  <FormattedMessage
                    id='visibility_modal.helper.searchability_editing'
                    defaultMessage="Searchability can't be changed after a post is published."
                  />
                </p>
              )}
            </div>

            <div
              ref={saveRef}
              className={classNames('visibility-dropdown', {
                disabled: disableQuotePolicy,
              })}
            >
              {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
              <label className='visibility-dropdown__label' id={quoteLabelId}>
                <FormattedMessage
                  id='visibility_modal.quote_label'
                  defaultMessage='Who can quote'
                />
              </label>

              <Dropdown
                items={quoteItems}
                current={disableQuotePolicy ? 'nobody' : quotePolicy}
                onChange={handleQuotePolicyChange}
                labelId={quoteLabelId}
                descriptionId={quoteDescriptionId}
                classPrefix='visibility-dropdown'
                disabled={disableQuotePolicy}
              />
              <QuotePolicyHelper
                policy={quotePolicy}
                visibility={visibility}
                className='visibility-dropdown__helper'
                id={quoteDescriptionId}
              />
            </div>

            {isQuotePost && visibility === 'direct' && (
              <div className='visibility-modal__quote-warning'>
                <FormattedMessage
                  id='visibility_modal.direct_quote_warning.title'
                  defaultMessage="Quotes can't be embedded in private mentions"
                  tagName='h3'
                />
                <FormattedMessage
                  id='visibility_modal.direct_quote_warning.text'
                  defaultMessage='If you save the current settings, the embedded quote will be converted to a link.'
                  tagName='p'
                />
              </div>
            )}
          </div>
          <div className='dialog-modal__content__actions'>
            <Button onClick={onClose} secondary>
              <FormattedMessage
                id='confirmation_modal.cancel'
                defaultMessage='Cancel'
              />
            </Button>
            <Button onClick={handleSave} disabled={disableSave}>
              <FormattedMessage
                id='visibility_modal.save'
                defaultMessage='Save'
              />
            </Button>
          </div>
        </div>
      </div>
    );
  },
);
VisibilityModal.displayName = 'VisibilityModal';

const QuotePolicyHelper: FC<
  {
    policy: ApiQuotePolicy;
    visibility: StatusVisibility;
  } & React.ComponentPropsWithoutRef<'p'>
> = ({ policy, visibility, ...otherProps }) => {
  let hintText: React.ReactElement | undefined;

  if (visibility === 'unlisted' && policy !== 'nobody') {
    hintText = (
      <FormattedMessage
        id='visibility_modal.helper.unlisted_quoting'
        defaultMessage='When people quote you, their post will also be hidden from trending timelines.'
      />
    );
  }

  if (visibility === 'private') {
    hintText = (
      <FormattedMessage
        id='visibility_modal.helper.private_quoting'
        defaultMessage="Follower-only posts authored on Mastodon can't be quoted by others."
      />
    );
  }

  if (visibility === 'direct') {
    hintText = (
      <FormattedMessage
        id='visibility_modal.helper.direct_quoting'
        defaultMessage="Private mentions authored on Mastodon can't be quoted by others."
      />
    );
  }

  if (!hintText) {
    return null;
  }

  return <p {...otherProps}>{hintText}</p>;
};
