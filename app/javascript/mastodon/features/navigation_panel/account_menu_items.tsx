import { useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import {
  UserIcon,
  GearIcon,
  CirclesFourIcon,
  UserCircleIcon,
  HeartIcon,
  BookmarkSimpleIcon,
  UsersThreeIcon,
  ProhibitIcon,
  SignOutIcon,
  BellSlashIcon,
  HandWavingIcon,
  ArrowCircleUpIcon,
} from '@phosphor-icons/react';

import { openModal } from '@/mastodon/actions/modal';
import { Avatar } from '@/mastodon/components/avatar';
import { DisplayName } from '@/mastodon/components/display_name';
import { useAccountHandle } from '@/mastodon/components/display_name/default';
import { LockupContent, LockupWrapper } from '@/mastodon/components/lockup';
import {
  MenuItem,
  MenuItemDivider,
  MenuItemGroup,
  MenuItemLink,
} from '@/mastodon/components/menu';
import { useAccount } from '@/mastodon/hooks/useAccount';
import { useIdentity } from '@/mastodon/identity_context';
import { useAppDispatch } from '@/mastodon/store';

import { useBreakpoint } from '../ui/hooks/useBreakpoint';

import classes from './account_menu_items.module.scss';

export const AccountMenuItems: React.FC<{
  context?: 'default' | 'mobile';
}> = ({ context = 'default' }) => {
  const dispatch = useAppDispatch();
  const { accountId } = useIdentity();
  const account = useAccount(accountId);

  const confirmLogout = useCallback(() => {
    dispatch(openModal({ modalType: 'CONFIRM_LOG_OUT', modalProps: {} }));
  }, [dispatch]);

  const isMobile = useBreakpoint('openable');

  const handleRefresh = useCallback(() => {
    window.location.reload();
  }, []);

  if (!accountId) {
    return null;
  }

  const accountBasePath = `/@${account?.acct}`;

  return (
    <>
      <ProfileMenuItem />

      <MenuItemLink to={accountBasePath} exact icon={UserIcon}>
        <FormattedMessage
          id='account.view_profile'
          defaultMessage='View Profile'
        />
      </MenuItemLink>

      <MenuItemLink as='a' href='/settings/preferences' icon={GearIcon}>
        <FormattedMessage id='tabs_bar.settings' defaultMessage='Settings' />
      </MenuItemLink>

      <MenuItemDivider />

      <MenuItemLink
        to={`${accountBasePath}/collections`}
        icon={CirclesFourIcon}
      >
        <FormattedMessage
          id='navigation_bar.collections'
          defaultMessage='Collections'
        />
      </MenuItemLink>

      <MenuItemLink to='/favourites' icon={HeartIcon}>
        <FormattedMessage
          id='navigation_bar.liked_posts'
          defaultMessage='Liked Posts'
        />
      </MenuItemLink>

      <MenuItemLink to='/emoji_reactions' icon={HeartIcon}>
        <FormattedMessage
          id='navigation_bar.reacted_with_emoji_posts'
          defaultMessage='Reacted Posts with Emoji'
        />
      </MenuItemLink>

      {context === 'mobile' && (
        <MenuItemLink to='/bookmark_categories' icon={BookmarkSimpleIcon}>
          <FormattedMessage
            id='navigation_bar.saved_posts'
            defaultMessage='Saved Posts'
          />
        </MenuItemLink>
      )}

      <MenuItemLink to='/circles' icon={UserCircleIcon}>
        <FormattedMessage
          id='navigation_bar.circles'
          defaultMessage='Circles'
        />
      </MenuItemLink>

      <MenuItemDivider />

      <MenuItemLink to='/reaction_deck' icon={HeartIcon}>
        <FormattedMessage
          id='navigation_bar.reaction_deck'
          defaultMessage='Emoji deck'
        />
      </MenuItemLink>

      <MenuItemDivider />

      <MenuItemGroup
        label={
          <FormattedMessage
            id='navigation_bar.relationships'
            defaultMessage='Relationships'
          />
        }
      >
        <MenuItemLink to={`${accountBasePath}/followers`} icon={HandWavingIcon}>
          <FormattedMessage
            id='navigation_bar.followers'
            defaultMessage='Followers'
          />
        </MenuItemLink>

        <MenuItemLink to={`${accountBasePath}/following`} icon={UsersThreeIcon}>
          <FormattedMessage
            id='navigation_bar.following'
            defaultMessage='Following'
          />
        </MenuItemLink>

        <MenuItemLink to='/mutes' icon={BellSlashIcon}>
          <FormattedMessage id='navigation_bar.muted' defaultMessage='Muted' />
        </MenuItemLink>

        <MenuItemLink to='/blocks' icon={ProhibitIcon}>
          <FormattedMessage
            id='navigation_bar.blocked'
            defaultMessage='Blocked'
          />
        </MenuItemLink>
      </MenuItemGroup>

      <MenuItemDivider />

      {isMobile && (
        <MenuItemLink to='#' onClick={handleRefresh} icon={ArrowCircleUpIcon}>
          <FormattedMessage
            id='navigation_bar.refresh'
            defaultMessage='Refresh'
          />
        </MenuItemLink>
      )}

      <MenuItem onClick={confirmLogout} icon={SignOutIcon}>
        <FormattedMessage
          id='navigation_bar.sign_out'
          defaultMessage='Sign Out'
        />
      </MenuItem>
    </>
  );
};

const ProfileMenuItem: React.FC = () => {
  const { accountId } = useIdentity();
  const account = useAccount(accountId);
  const handle = useAccountHandle(account);

  if (!accountId) {
    return null;
  }

  const accountBasePath = `/@${account?.acct}`;

  return (
    <MenuItemLink to={accountBasePath} exact>
      <LockupWrapper
        icon={<Avatar account={account} size={40} />}
        className={classes.profileMenuItem}
      >
        <LockupContent subtitle={handle}>
          <DisplayName variant='simple' account={account} />
        </LockupContent>
      </LockupWrapper>
    </MenuItemLink>
  );
};
