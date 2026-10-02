import { useCallback, useEffect, useState } from 'react';

import { FormattedMessage } from 'react-intl';

import {
  ChatCircleDotsIcon,
  MagnifyingGlassIcon,
  CloudIcon,
  NewspaperIcon,
  QuotesIcon,
  KeyIcon,
} from '@phosphor-icons/react';

import {
  changeComposeVisibility,
  setComposeQuotePolicy,
} from '@/mastodon/actions/compose_typed';
import { openModal } from '@/mastodon/actions/modal';
import type { ApiQuotePolicy } from '@/mastodon/api_types/quotes';
import type { StatusVisibility } from '@/mastodon/api_types/statuses';
import { Button, CaretIcon } from '@/mastodon/components/button/redesign';
import { DisplayNameSimple } from '@/mastodon/components/display_name/simple';
import {
  Menu,
  MenuList,
  MenuTrigger,
  MenuItemDivider,
  MenuItemGroup,
  MenuItem,
  MenuItemRadio,
  MenuItemCheckbox,
} from '@/mastodon/components/menu';
import { selectPlainAccount } from '@/mastodon/selectors/accounts';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';

import { selectComposeMentions, selectComposePrivacy } from './selectors';

export const ComposeVisibility: React.FC<{ className?: string }> = ({
  className,
}) => {
  const privacy = useAppSelector(selectComposePrivacy);
  const isEditing = useAppSelector((state) => !!state.compose.get('id'));

  return (
    <div className={className}>
      <FormattedMessage
        id='compose.post.to'
        defaultMessage='To:'
        description='Before button that indicates who a post is for (Public, Followers, mentioned people)'
      />
      <Menu>
        <MenuTrigger
          as={Button}
          size='sm'
          trailingIcon={CaretIcon}
          disabled={isEditing}
        >
          <ComposeVisibilityButtonText privacy={privacy} />
        </MenuTrigger>

        {privacy !== 'direct' ? (
          <ComposeVisibilityMenu />
        ) : (
          <ComposeDirectMenu />
        )}
      </Menu>
    </div>
  );
};

const ComposeVisibilityButtonText: React.FC<{
  privacy: StatusVisibility;
}> = ({ privacy }) => {
  const mentions = useAppSelector(selectComposeMentions);
  const firstMentionedAccount = useAppSelector((state) =>
    selectPlainAccount(state, mentions.at(0)),
  );

  if (['public', 'unlisted', 'public_unlisted', 'login'].includes(privacy)) {
    return (
      <FormattedMessage id='privacy.public.short' defaultMessage='Public' />
    );
  } else if (privacy === 'private') {
    return (
      <FormattedMessage
        id='compose.post.privacy.followers'
        defaultMessage='Followers {count, plural, =0 {} one {+ # other} other {+ # others}}'
        description='Count is # of other people mentioned in the post. If zero, just output "Followers".'
        values={{ count: mentions.length }}
      />
    );
  } else if (privacy === 'mutual') {
    return (
      <FormattedMessage id='privacy.mutual.short' defaultMessage='Mutual' />
    );
  } else if (mentions.length > 0) {
    return (
      <FormattedMessage
        id='compose.message.direct.followers'
        defaultMessage='{name} {count, plural, =0 {} one {+ # other} other {+ # others}}'
        description='Name is the primary display name, count is # of other people mentioned in the post'
        values={{
          name: <DisplayNameSimple account={firstMentionedAccount} />,
          count: mentions.length - 1,
        }}
      />
    );
  }

  return '-';
};

const ComposeVisibilityMenu: React.FC = () => {
  const privacy = useAppSelector(selectComposePrivacy);
  const defaultPrivacy = useAppSelector(
    (state) => state.compose.get('default_privacy') as StatusVisibility,
  );
  const currentQuotePolicy = useAppSelector(
    (state) => state.compose.get('quote_policy') as ApiQuotePolicy | undefined,
  );
  const defaultQuotePolicy = useAppSelector(
    (state) => state.compose.get('default_quote_policy') as ApiQuotePolicy,
  );

  // Track the last public quote policy, so the picker remembers what was last used before quoting was disabled.
  const [lastQuotePolicy, setLastQuotePolicy] = useState(
    defaultQuotePolicy !== 'nobody' ? defaultQuotePolicy : 'public',
  );
  const quotePolicy = currentQuotePolicy ?? defaultQuotePolicy;

  const isReply = useAppSelector((state) => !!state.compose.get('in_reply_to'));

  const [discoverableCheck, setDiscoverableCheck] = useState(true);
  const [discoverableInRemoteCheck, setDiscoverableInRemoteCheck] =
    useState(true);
  const [loginOnlyCheck, setLoginOnlyCheck] = useState(false);

  const dispatch = useAppDispatch();
  useEffect(() => {
    const updatePrivacy = (p: StatusVisibility) => {
      if (privacy !== p) {
        dispatch(changeComposeVisibility(p));
      }
    };

    if (['public', 'unlisted', 'public_unlisted', 'login'].includes(privacy)) {
      if (discoverableCheck && loginOnlyCheck) {
        updatePrivacy('login');
      } else if (discoverableCheck && discoverableInRemoteCheck) {
        updatePrivacy('public');
      } else if (discoverableCheck && !discoverableInRemoteCheck) {
        updatePrivacy('public_unlisted');
      } else if (!discoverableCheck) {
        updatePrivacy('unlisted');
      }
    }
  }, [
    dispatch,
    privacy,
    discoverableCheck,
    discoverableInRemoteCheck,
    loginOnlyCheck,
  ]);

  const handlePrivacyChange = useCallback(
    ({ value }: { value: string }) => {
      switch (value) {
        case 'discoverable':
          setDiscoverableCheck(!discoverableCheck);
          return;
        case 'discoverableInRemote':
          setDiscoverableInRemoteCheck(!discoverableInRemoteCheck);
          return;
        case 'loginOnly':
          setLoginOnlyCheck(!loginOnlyCheck);
          return;
      }

      // Logic in upstream mastodon
      if (value === 'private' && privacy !== 'private') {
        dispatch(changeComposeVisibility(value));
      } else if (value === 'mutual' && privacy !== 'mutual') {
        dispatch(changeComposeVisibility(value));
      } else if (value === 'public' && privacy === 'private') {
        dispatch(
          changeComposeVisibility(
            defaultPrivacy === 'unlisted' ? 'unlisted' : 'public',
          ),
        );
      } else if (value === 'unlisted' && privacy !== 'private') {
        dispatch(
          changeComposeVisibility(privacy === 'public' ? 'unlisted' : 'public'),
        );
      }
    },
    [
      defaultPrivacy,
      dispatch,
      privacy,
      discoverableCheck,
      discoverableInRemoteCheck,
      loginOnlyCheck,
      setDiscoverableCheck,
      setDiscoverableInRemoteCheck,
      setLoginOnlyCheck,
    ],
  );

  const handleQuotePolicyChange = useCallback(
    ({ value, checked }: { value: string; checked?: boolean }) => {
      let newQuotePolicy: ApiQuotePolicy = 'nobody';
      switch (value) {
        case 'public':
          newQuotePolicy = 'public';
          setLastQuotePolicy(newQuotePolicy);
          break;
        case 'followers':
          newQuotePolicy = 'followers';
          setLastQuotePolicy(newQuotePolicy);
          break;
        case 'others':
          // If it's not checked, then it's nobody.
          if (checked) {
            // Only use the default if it's not nobody, as then it'll never be enabled.
            newQuotePolicy = lastQuotePolicy;
          }
          break;
      }
      dispatch(setComposeQuotePolicy(newQuotePolicy));
    },
    [dispatch, lastQuotePolicy],
  );

  const handleSwitchToMessage: React.MouseEventHandler<HTMLButtonElement> =
    useCallback(() => {
      dispatch(changeComposeVisibility('direct'));
    }, [dispatch]);

  return (
    <MenuList placement='bottom-start' offset={4} maxWidth={280}>
      <MenuItemGroup
        label={
          <FormattedMessage
            id='compose.visibility.title'
            defaultMessage='Visibility'
          />
        }
      >
        <MenuItemRadio
          name='visibility'
          value='public'
          checked={['public', 'unlisted', 'public_unlisted', 'login'].includes(
            privacy,
          )}
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
        >
          <FormattedMessage id='privacy.public.short' defaultMessage='Public' />
        </MenuItemRadio>

        <MenuItemRadio
          name='visibility'
          value='private'
          checked={privacy === 'private'}
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='privacy.private.short'
            defaultMessage='Followers'
          />
        </MenuItemRadio>

        <MenuItemRadio
          name='visibility'
          value='mutual'
          checked={['mutual'].includes(privacy)}
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
        >
          <FormattedMessage id='privacy.mutual.short' defaultMessage='Mutual' />
        </MenuItemRadio>

        <MenuItemDivider />

        <MenuItemCheckbox
          value='discoverable'
          disabled={
            !['public', 'unlisted', 'public_unlisted', 'login'].includes(
              privacy,
            )
          }
          checked={discoverableCheck}
          onChange={handlePrivacyChange}
          icon={MagnifyingGlassIcon}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='compose.discoverable'
            defaultMessage='Discoverable in public feeds & search results'
          />
        </MenuItemCheckbox>

        <MenuItemCheckbox
          value='discoverableInRemote'
          disabled={!['public', 'public_unlisted'].includes(privacy)}
          checked={discoverableInRemoteCheck && privacy === 'public'}
          onChange={handlePrivacyChange}
          icon={CloudIcon}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='compose.fediverse_discoverable'
            defaultMessage='Discoverable in fediverse'
          />
        </MenuItemCheckbox>

        <MenuItemCheckbox
          value='loginOnly'
          disabled={!['public', 'login'].includes(privacy)}
          checked={loginOnlyCheck && privacy === 'login'}
          onChange={handlePrivacyChange}
          icon={KeyIcon}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='compose.login_only'
            defaultMessage='Login user only'
          />
        </MenuItemCheckbox>

        <MenuItemCheckbox
          value='others'
          disabled={
            !['public', 'unlisted', 'public_unlisted', 'login'].includes(
              privacy,
            )
          }
          checked={
            quotePolicy !== 'nobody' &&
            ['public', 'unlisted', 'public_unlisted', 'login'].includes(privacy)
          }
          onChange={handleQuotePolicyChange}
          icon={QuotesIcon}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='compose.quotable'
            defaultMessage='Allow others to quote'
          />
        </MenuItemCheckbox>
      </MenuItemGroup>

      {quotePolicy !== 'nobody' &&
        ['public', 'unlisted', 'public_unlisted', 'login'].includes(
          privacy,
        ) && (
          <MenuItemGroup
            label={
              <FormattedMessage
                id='compose.visibility.quote_policy'
                defaultMessage='Who can quote'
              />
            }
          >
            <MenuItemRadio
              name='quote_policy'
              value='public'
              checked={quotePolicy === 'public'}
              onChange={handleQuotePolicyChange}
              keepMenuOpenOnClick
            >
              <FormattedMessage
                id='compose.visibility.quote_policy.anyone'
                defaultMessage='Anyone'
              />
            </MenuItemRadio>

            <MenuItemRadio
              name='quote_policy'
              value='followers'
              checked={quotePolicy === 'followers'}
              onChange={handleQuotePolicyChange}
              keepMenuOpenOnClick
            >
              <FormattedMessage
                id='compose.visibility.quote_policy.followers'
                defaultMessage='Followers'
              />
            </MenuItemRadio>
          </MenuItemGroup>
        )}

      <MenuItemDivider />

      <MenuItem icon={ChatCircleDotsIcon} onClick={handleSwitchToMessage}>
        {isReply ? (
          <FormattedMessage
            id='compose.post.to_private_reply'
            defaultMessage='Reply privately instead'
          />
        ) : (
          <FormattedMessage
            id='compose.post.to_message'
            defaultMessage='Compose a message instead'
            description='Message refers to a direct message. For languages where this is confusing, "chat" or "direct message" can be used.'
          />
        )}
      </MenuItem>
    </MenuList>
  );
};

const ComposeDirectMenu: React.FC = () => {
  const dispatch = useAppDispatch();
  const handleSwitchToPost: React.MouseEventHandler<HTMLButtonElement> =
    useCallback(() => {
      dispatch(
        openModal({ modalType: 'COMPOSER_SWITCH_TO_POST', modalProps: {} }),
      );
    }, [dispatch]);

  const isReply = useAppSelector((state) => !!state.compose.get('in_reply_to'));

  return (
    <MenuList placement='bottom-start' offset={4} maxWidth={280}>
      <MenuItemGroup
        label={
          <FormattedMessage
            id='compose.visibility.title'
            defaultMessage='Visibility'
          />
        }
      >
        <MenuItemRadio value='direct' disabled checked>
          <FormattedMessage
            id='compose.visibility.direct_note'
            defaultMessage='Everyone mentioned'
          />
        </MenuItemRadio>
      </MenuItemGroup>

      <MenuItemDivider />

      <MenuItem icon={NewspaperIcon} onClick={handleSwitchToPost}>
        {isReply ? (
          <FormattedMessage
            id='compose.visibility.to_reply'
            defaultMessage='Reply publicly instead'
          />
        ) : (
          <FormattedMessage
            id='compose.visibility.to_post'
            defaultMessage='Compose a post instead'
          />
        )}
      </MenuItem>
    </MenuList>
  );
};
