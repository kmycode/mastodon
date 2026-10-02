import { useCallback, useEffect, useState } from 'react';

import { FormattedMessage } from 'react-intl';

import classNames from 'classnames';

import {
  ChatCircleDotsIcon,
  EyeIcon,
  CloudIcon,
  KeyIcon,
} from '@phosphor-icons/react';

import { changeComposeVisibility } from '@/mastodon/actions/compose_typed';
import type { StatusVisibility } from '@/mastodon/api_types/statuses';
import { Button, CaretIcon } from '@/mastodon/components/button/redesign';
import { Icon } from '@/mastodon/components/icon';
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
import { Tooltip } from '@/mastodon/components/tooltip';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';

import { selectComposePrivacy } from './selectors';
import classes from './styles.module.scss';

export const ComposeVisibility: React.FC<{ className?: string }> = ({
  className,
}) => {
  const privacy = useAppSelector(selectComposePrivacy);
  const isEditing = useAppSelector((state) => !!state.compose.get('id'));

  if (privacy === 'direct') {
    return (
      <div className={classNames(className, classes.toolbarMessage)}>
        <Icon icon={EyeIcon} />
        <FormattedMessage
          id='compose.privacy.direct.hint'
          defaultMessage='Visible to everyone mentioned. Not encrypted.'
        />
      </div>
    );
  }

  if (isEditing) {
    return (
      <div className={className}>
        <Tooltip
          renderTextWhenClosed
          text={
            <FormattedMessage
              id='compose.privacy.editing'
              defaultMessage='Visibility can’t be edited after a post has been published.'
            />
          }
        >
          {({ getTooltipProps, tooltipId }) => (
            <Button
              {...getTooltipProps()}
              size='sm'
              aria-disabled
              aria-describedby={tooltipId}
            >
              <ComposeVisibilityButtonText privacy={privacy} />
            </Button>
          )}
        </Tooltip>
      </div>
    );
  }

  return (
    <div className={className}>
      <Menu>
        <MenuTrigger as={Button} size='sm' trailingIcon={CaretIcon}>
          <ComposeVisibilityButtonText privacy={privacy} />
        </MenuTrigger>

        <ComposeVisibilityMenu />
      </Menu>
    </div>
  );
};

const ComposeVisibilityButtonText: React.FC<{
  privacy: StatusVisibility;
}> = ({ privacy }) => {
  if (['public', 'unlisted', 'public_unlisted', 'login'].includes(privacy)) {
    return (
      <FormattedMessage id='privacy.public.short' defaultMessage='Public' />
    );
  } else if (privacy === 'unlisted') {
    return (
      <FormattedMessage
        id='compose.privacy.unlisted'
        defaultMessage='Public, hidden from search'
      />
    );
  } else if (privacy === 'private') {
    return (
      <FormattedMessage
        id='compose.privacy.followers'
        defaultMessage='Followers (+ mentions)'
      />
    );
  } else if (privacy === 'mutual') {
    return (
      <FormattedMessage id='privacy.mutual.short' defaultMessage='Mutual' />
    );
  }

  return '-';
};

const ComposeVisibilityMenu: React.FC = () => {
  const privacy = useAppSelector(selectComposePrivacy);
  const defaultPrivacy = useAppSelector(
    (state) => state.compose.get('default_privacy') as StatusVisibility,
  );

  const isReply = useAppSelector((state) => !!state.compose.get('in_reply_to'));

  const [discoverableCheck, setDiscoverableCheck] = useState(false);
  const [discoverableInRemoteCheck, setDiscoverableInRemoteCheck] =
    useState(false);
  const [loginOnlyCheck, setLoginOnlyCheck] = useState(false);

  const dispatch = useAppDispatch();
  useEffect(() => {
    const updatePrivacy = (p: StatusVisibility) => {
      if (privacy !== p) {
        dispatch(changeComposeVisibility(p));
      }
    };

    if (['public', 'unlisted', 'public_unlisted', 'login'].includes(privacy)) {
      if (!discoverableCheck && loginOnlyCheck) {
        updatePrivacy('login');
      } else if (!discoverableCheck && !discoverableInRemoteCheck) {
        updatePrivacy('public');
      } else if (!discoverableCheck && discoverableInRemoteCheck) {
        updatePrivacy('public_unlisted');
      } else if (discoverableCheck) {
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
        case 'notDiscoverable':
          setDiscoverableCheck(!discoverableCheck);
          return;
        case 'notDiscoverableInRemote':
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
          {privacy}
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
            id='compose.privacy.followers'
            defaultMessage='Followers (+ mentions)'
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
          value='notDiscoverable'
          disabled={
            !['public', 'unlisted', 'public_unlisted', 'login'].includes(
              privacy,
            )
          }
          checked={
            discoverableCheck &&
            !['public', 'unlisted', 'public_unlisted', 'login'].includes(
              privacy,
            )
          }
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
          description={
            <FormattedMessage
              id='compose.discoverable.hint'
              defaultMessage='Also applies to discovery feeds'
            />
          }
        >
          <FormattedMessage
            id='compose.discoverable'
            defaultMessage='Hide from search results'
          />
        </MenuItemCheckbox>

        <MenuItemCheckbox
          value='notDiscoverableInRemote'
          disabled={!['public', 'public_unlisted'].includes(privacy)}
          checked={
            discoverableInRemoteCheck && !['public', 'login'].includes(privacy)
          }
          onChange={handlePrivacyChange}
          icon={CloudIcon}
          keepMenuOpenOnClick
        >
          <FormattedMessage
            id='compose.fediverse_discoverable'
            defaultMessage='Hide from search results in fediverse'
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
      </MenuItemGroup>

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
            defaultMessage='Convert to private message'
            description='Message refers to a direct message. For languages where this is confusing, "chat" or "direct message" can be used.'
          />
        )}
      </MenuItem>
    </MenuList>
  );
};
