import { useCallback, useState } from 'react';

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
import { Button, CaretIcon } from '@/mastodon/components/button';
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

import classes from '../styles.module.scss';

import { selectComposePrivacy } from './selectors';

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

export const ComposeVisibilityButtonText: React.FC<{
  privacy: StatusVisibility;
}> = ({ privacy }) => {
  if (privacy === 'public') {
    return (
      <FormattedMessage id='privacy.public.short' defaultMessage='Public' />
    );
  } else if (privacy === 'public_unlisted') {
    return (
      <FormattedMessage
        id='privacy.public_unlisted.short'
        defaultMessage='Local public'
      />
    );
  } else if (privacy === 'login') {
    return (
      <FormattedMessage id='privacy.login.short' defaultMessage='Login only' />
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
  } else if (privacy === 'circle') {
    return (
      <FormattedMessage id='privacy.circle.short' defaultMessage='Circle' />
    );
  } else if (privacy === 'reply') {
    return <FormattedMessage id='privacy.reply.short' defaultMessage='Reply' />;
  }

  return `Unknown: ${privacy}`;
};

const ComposeVisibilityMenu: React.FC = () => {
  const privacy = useAppSelector(selectComposePrivacy);
  const originalPrivacy = useAppSelector(
    (state) => state.compose.get('privacy') as StatusVisibility | null,
  );
  const defaultPrivacy = useAppSelector(
    (state) => state.compose.get('default_privacy') as StatusVisibility,
  );

  const isReply = useAppSelector((state) => !!state.compose.get('in_reply_to'));
  const isReplyToLimited = useAppSelector(
    (state) => !!state.compose.get('reply_to_limited'),
  );

  const [discoverableCheck, setDiscoverableCheck] = useState(false);
  const [discoverableInRemoteCheck, setDiscoverableInRemoteCheck] =
    useState(false);
  const [loginOnlyCheck, setLoginOnlyCheck] = useState(false);

  const dispatch = useAppDispatch();

  const handlePrivacyChange = useCallback(
    ({ value }: { value: string }) => {
      const updatePrivacy = (p: StatusVisibility) => {
        if (privacy !== p) {
          dispatch(changeComposeVisibility(p));
        }
      };

      switch (value) {
        case 'notDiscoverable':
          {
            const newValue = originalPrivacy
              ? !discoverableCheck
              : defaultPrivacy === 'unlisted';
            setDiscoverableCheck(newValue);
            updatePrivacy(newValue ? 'unlisted' : 'public');
          }
          return;
        case 'notDiscoverableInRemote':
          {
            const newValue = originalPrivacy
              ? !discoverableInRemoteCheck
              : defaultPrivacy === 'public_unlisted';
            setDiscoverableInRemoteCheck(newValue);
            updatePrivacy(newValue ? 'public_unlisted' : 'public');
          }
          return;
        case 'loginOnly':
          {
            const newValue = originalPrivacy
              ? !loginOnlyCheck
              : defaultPrivacy === 'login';
            setLoginOnlyCheck(newValue);
            updatePrivacy(newValue ? 'login' : 'public');
          }
          return;
      }

      if (value === privacy) return;

      // Logic in upstream mastodon
      // on change from list (not toggle)
      if (value === 'public') {
        updatePrivacy(
          ['unlisted', 'public_unlisted', 'login'].includes(defaultPrivacy)
            ? defaultPrivacy
            : 'public',
        );

        switch (defaultPrivacy) {
          case 'unlisted':
            setDiscoverableCheck(true);
            break;
          case 'public_unlisted':
            setDiscoverableInRemoteCheck(true);
            break;
          case 'login':
            setLoginOnlyCheck(true);
            break;
        }
      } else if (value === 'unlisted') {
        updatePrivacy(privacy === 'public' ? 'unlisted' : 'public');
      } else if (['private', 'mutual', 'circle', 'reply'].includes(value)) {
        updatePrivacy(value as StatusVisibility);
      }
    },
    [
      defaultPrivacy,
      originalPrivacy,
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
          checked={privacy === 'mutual'}
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
        >
          <FormattedMessage id='privacy.mutual.short' defaultMessage='Mutual' />
        </MenuItemRadio>

        <MenuItemRadio
          name='visibility'
          value='circle'
          checked={privacy === 'circle'}
          onChange={handlePrivacyChange}
          keepMenuOpenOnClick
        >
          <FormattedMessage id='privacy.circle.short' defaultMessage='Circle' />
        </MenuItemRadio>

        {isReplyToLimited && (
          <MenuItemRadio
            name='visibility'
            value='reply'
            checked={privacy === 'reply'}
            onChange={handlePrivacyChange}
            keepMenuOpenOnClick
          >
            <FormattedMessage id='privacy.reply.short' defaultMessage='Reply' />
          </MenuItemRadio>
        )}

        <MenuItemDivider />

        <MenuItemCheckbox
          value='notDiscoverable'
          disabled={!['public', 'unlisted'].includes(privacy)}
          checked={privacy === 'unlisted'}
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
          checked={privacy === 'public_unlisted'}
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
          checked={privacy === 'login'}
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
