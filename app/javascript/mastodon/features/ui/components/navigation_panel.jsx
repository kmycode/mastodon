import PropTypes from 'prop-types';
import { Component, useEffect } from 'react';

import { defineMessages, injectIntl, useIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import { useSelector, useDispatch } from 'react-redux';

import CirclesIcon from '@/material-icons/400-24px/account_circle-fill.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import BookmarksActiveIcon from '@/material-icons/400-24px/bookmarks-fill.svg?react';
import BookmarksIcon from '@/material-icons/400-24px/bookmarks.svg?react';
import ExploreActiveIcon from '@/material-icons/400-24px/explore-fill.svg?react';
import ExploreIcon from '@/material-icons/400-24px/explore.svg?react';
import ModerationIcon from '@/material-icons/400-24px/gavel.svg?react';
import PeopleIcon from '@/material-icons/400-24px/group.svg?react';
import HomeActiveIcon from '@/material-icons/400-24px/home-fill.svg?react';
import HomeIcon from '@/material-icons/400-24px/home.svg?react';
import ListAltActiveIcon from '@/material-icons/400-24px/list_alt-fill.svg?react';
import ListAltIcon from '@/material-icons/400-24px/list_alt.svg?react';
import AdministrationIcon from '@/material-icons/400-24px/manufacturing.svg?react';
import MoreHorizIcon from '@/material-icons/400-24px/more_horiz.svg?react';
import NotificationsActiveIcon from '@/material-icons/400-24px/notifications-fill.svg?react';
import NotificationsIcon from '@/material-icons/400-24px/notifications.svg?react';
import PersonAddActiveIcon from '@/material-icons/400-24px/person_add-fill.svg?react';
import PersonAddIcon from '@/material-icons/400-24px/person_add.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import SearchIcon from '@/material-icons/400-24px/search.svg?react';
import SettingsIcon from '@/material-icons/400-24px/settings.svg?react';
import StarActiveIcon from '@/material-icons/400-24px/star-fill.svg?react';
import StarIcon from '@/material-icons/400-24px/star.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchFollowRequests } from 'mastodon/actions/accounts';
import { IconWithBadge } from 'mastodon/components/icon_with_badge';
import { WordmarkLogo } from 'mastodon/components/logo';
import { NavigationPortal } from 'mastodon/components/navigation_portal';
import { identityContextPropShape, withIdentity } from 'mastodon/identity_context';
import { enableDtlMenu, timelinePreview, trendsEnabled, dtlTag, enableLocalTimeline, isHideItem } from 'mastodon/initial_state';
import { transientSingleColumn } from 'mastodon/is_mobile';
import { canManageReports, canViewAdminDashboard } from 'mastodon/permissions';
import { selectUnreadNotificationGroupsCount } from 'mastodon/selectors/notifications';
import { selectUseGroupedNotifications } from 'mastodon/selectors/settings';

import ColumnLink from './column_link';
import DisabledAccountBanner from './disabled_account_banner';
import { ListPanel } from './list_panel';
import SignInBanner from './sign_in_banner';

const messages = defineMessages({
  home: { id: 'tabs_bar.home', defaultMessage: 'Home' },
  notifications: { id: 'tabs_bar.notifications', defaultMessage: 'Notifications' },
  explore: { id: 'explore.title', defaultMessage: 'Explore' },
  local: { id: 'column.local', defaultMessage: 'Local' },
  deepLocal: { id: 'column.deep_local', defaultMessage: 'Deep' },
  firehose: { id: 'column.firehose', defaultMessage: 'Live feeds' },
  direct: { id: 'navigation_bar.direct', defaultMessage: 'Private mentions' },
  favourites: { id: 'navigation_bar.favourites', defaultMessage: 'Favorites' },
  bookmarks: { id: 'navigation_bar.bookmarks', defaultMessage: 'Bookmarks' },
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  antennas: { id: 'navigation_bar.antennas', defaultMessage: 'Antennas' },
  circles: { id: 'navigation_bar.circles', defaultMessage: 'Circles' },
  preferences: { id: 'navigation_bar.preferences', defaultMessage: 'Preferences' },
  administration: { id: 'navigation_bar.administration', defaultMessage: 'Administration' },
  moderation: { id: 'navigation_bar.moderation', defaultMessage: 'Moderation' },
  followsAndFollowers: { id: 'navigation_bar.follows_and_followers', defaultMessage: 'Follows and followers' },
  about: { id: 'navigation_bar.about', defaultMessage: 'About' },
  search: { id: 'navigation_bar.search', defaultMessage: 'Search' },
  advancedInterface: { id: 'navigation_bar.advanced_interface', defaultMessage: 'Open in advanced web interface' },
  openedInClassicInterface: { id: 'navigation_bar.opened_in_classic_interface', defaultMessage: 'Posts, accounts, and other specific pages are opened by default in the classic web interface.' },
  followRequests: { id: 'navigation_bar.follow_requests', defaultMessage: 'Follow requests' },
});

const NotificationsLink = () => {
  const optedInGroupedNotifications = useSelector(selectUseGroupedNotifications);
  const count = useSelector(state => state.getIn(['notifications', 'unread']));
  const intl = useIntl();

  const newCount = useSelector(selectUnreadNotificationGroupsCount);

  return (
    <ColumnLink
      key='notifications'
      transparent
      to='/notifications'
      icon={<IconWithBadge id='bell' icon={NotificationsIcon} count={optedInGroupedNotifications ? newCount : count} className='column-link__icon' />}
      activeIcon={<IconWithBadge id='bell' icon={NotificationsActiveIcon} count={optedInGroupedNotifications ? newCount : count} className='column-link__icon' />}
      text={intl.formatMessage(messages.notifications)}
    />
  );
};

const FollowRequestsLink = () => {
  const count = useSelector(state => state.getIn(['user_lists', 'follow_requests', 'items'])?.size ?? 0);
  const intl = useIntl();
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(fetchFollowRequests());
  }, [dispatch]);

  if (count === 0) {
    return null;
  }

  return (
    <ColumnLink
      transparent
      to='/follow_requests'
      icon={<IconWithBadge id='user-plus' icon={PersonAddIcon} count={count} className='column-link__icon' />}
      activeIcon={<IconWithBadge id='user-plus' icon={PersonAddActiveIcon} count={count} className='column-link__icon' />}
      text={intl.formatMessage(messages.followRequests)}
    />
  );
};

class NavigationPanel extends Component {
  static propTypes = {
    identity: identityContextPropShape,
    intl: PropTypes.object.isRequired,
  };

  isFirehoseActive = (match, location) => {
    return (match || location.pathname.startsWith('/public')) && !location.pathname.endsWith('/fixed');
  };

  isAntennasActive = (match, location) => {
    return (match || location.pathname.startsWith('/antennast'));
  };

  render () {
    const { intl } = this.props;
    const { signedIn, disabledAccountId, permissions } = this.props.identity;

    const explorer = (trendsEnabled ? (
      <ColumnLink transparent to='/explore' icon='explore' iconComponent={ExploreIcon} activeIconComponent={ExploreActiveIcon} text={intl.formatMessage(messages.explore)} />
    ) : (
      <ColumnLink transparent to='/search' icon='search' iconComponent={SearchIcon} text={intl.formatMessage(messages.search)} />
    ));
    
    let banner = undefined;

    if(transientSingleColumn)
      banner = (<div className='switch-to-advanced'>
        {intl.formatMessage(messages.openedInClassicInterface)}
        {" "}
        <a href={`/deck${location.pathname}`} className='switch-to-advanced__toggle'>
          {intl.formatMessage(messages.advancedInterface)}
        </a>
      </div>);

    return (
      <div className='navigation-panel'>
        <div className='navigation-panel__logo'>
          <Link to='/' className='column-link column-link--logo'><WordmarkLogo /></Link>
        </div>

        {banner &&
          <div className='navigation-panel__banner'>
            {banner}
          </div>
        }

        {signedIn && (
          <>
            <ColumnLink transparent to='/home' icon='home' iconComponent={HomeIcon} activeIconComponent={HomeActiveIcon} text={intl.formatMessage(messages.home)} />
            <NotificationsLink />
          </>
        )}

        {signedIn && enableLocalTimeline && (
          <ColumnLink transparent to='/public/local/fixed' icon='users' iconComponent={PeopleIcon} text={intl.formatMessage(messages.local)} />
        )}

        {signedIn && enableDtlMenu && dtlTag && (
          <ColumnLink transparent to={`/tags/${dtlTag}`} icon='users' iconComponent={PeopleIcon} text={intl.formatMessage(messages.deepLocal)} />
        )}

        {!signedIn && explorer}

        {signedIn && (
          <ColumnLink transparent to='/public' isActive={this.isFirehoseActive} icon='globe' iconComponent={PublicIcon} text={intl.formatMessage(messages.firehose)} />
        )}

        {(!signedIn && timelinePreview) && (
          <ColumnLink transparent to={enableLocalTimeline ? '/public/local' : '/public'} isActive={this.isFirehoseActive} icon='globe' iconComponent={PublicIcon} text={intl.formatMessage(messages.firehose)} />
        )}

        {signedIn && (
          <>
            <ListPanel />
            <hr />
          </>
        )}

        {signedIn && (
          <>
            <ColumnLink transparent to='/lists' icon='list-ul' iconComponent={ListAltIcon} activeIconComponent={ListAltActiveIcon} text={intl.formatMessage(messages.lists)} />
            <ColumnLink transparent to='/antennasw' icon='wifi' iconComponent={AntennaIcon} text={intl.formatMessage(messages.antennas)} isActive={this.isAntennasActive} />
            <ColumnLink transparent to='/circles' icon='user-circle' iconComponent={CirclesIcon} text={intl.formatMessage(messages.circles)} />
            <FollowRequestsLink />
            <ColumnLink transparent to='/conversations' icon='at' iconComponent={AlternateEmailIcon} text={intl.formatMessage(messages.direct)} />
          </>
        )}

        {signedIn && explorer}

        {signedIn && (
          <>
            <ColumnLink transparent to='/bookmark_categories' icon='bookmarks' iconComponent={BookmarksIcon} activeIconComponent={BookmarksActiveIcon} text={intl.formatMessage(messages.bookmarks)} />
            { !isHideItem('favourite_menu') && <ColumnLink transparent to='/favourites' icon='star' iconComponent={StarIcon} activeIconComponent={StarActiveIcon} text={intl.formatMessage(messages.favourites)} /> }
            <hr />

            <ColumnLink transparent href='/settings/preferences' icon='cog' iconComponent={SettingsIcon} text={intl.formatMessage(messages.preferences)} />

            {canManageReports(permissions) && <ColumnLink transparent href='/admin/reports' icon='flag' iconComponent={ModerationIcon} text={intl.formatMessage(messages.moderation)} />}
            {canViewAdminDashboard(permissions) && <ColumnLink transparent href='/admin/dashboard' icon='tachometer' iconComponent={AdministrationIcon} text={intl.formatMessage(messages.administration)} />}
          </>
        )}

        {!signedIn && (
          <div className='navigation-panel__sign-in-banner'>
            <hr />
            { disabledAccountId ? <DisabledAccountBanner /> : <SignInBanner /> }
          </div>
        )}

        <div className='navigation-panel__legal'>
          <hr />
          <ColumnLink transparent to='/about' icon='ellipsis-h' iconComponent={MoreHorizIcon} text={intl.formatMessage(messages.about)} />
        </div>

        <NavigationPortal />
      </div>
    );
  }

}

export default injectIntl(withIdentity(NavigationPanel));
