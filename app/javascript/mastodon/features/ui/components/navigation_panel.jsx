import PropTypes from 'prop-types';
import { Component } from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import { WordmarkLogo } from 'mastodon/components/logo';
import NavigationPortal from 'mastodon/components/navigation_portal';
import { timelinePreview, showTrends } from 'mastodon/initial_state';

import ColumnLink from './column_link';
import DisabledAccountBanner from './disabled_account_banner';
import FollowRequestsColumnLink from './follow_requests_column_link';
import ListPanel from './list_panel';
import NotificationsCounterIcon from './notifications_counter_icon';
import SignInBanner from './sign_in_banner';

const messages = defineMessages({
  home: { id: 'tabs_bar.home', defaultMessage: 'Home' },
  notifications: { id: 'tabs_bar.notifications', defaultMessage: 'Notifications' },
  explore: { id: 'explore.title', defaultMessage: 'Explore' },
  local: { id: 'tabs_bar.local_timeline', defaultMessage: 'Local' },
  federated: { id: 'tabs_bar.federated_timeline', defaultMessage: 'Federated' },
  direct: { id: 'navigation_bar.direct', defaultMessage: 'Private mentions' },
  favourites: { id: 'navigation_bar.favourites', defaultMessage: 'Favourites' },
  bookmarks: { id: 'navigation_bar.bookmarks', defaultMessage: 'Bookmarks' },
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  preferences: { id: 'navigation_bar.preferences', defaultMessage: 'Preferences' },
  followsAndFollowers: { id: 'navigation_bar.follows_and_followers', defaultMessage: 'Follows and followers' },
  about: { id: 'navigation_bar.about', defaultMessage: 'About' },
  search: { id: 'navigation_bar.search', defaultMessage: 'Search' },
});

class NavigationPanel extends Component {

  static contextTypes = {
    router: PropTypes.object.isRequired,
    identity: PropTypes.object.isRequired,
  };

  static propTypes = {
    intl: PropTypes.object.isRequired,
  };

  render () {
    const { intl } = this.props;
    const { signedIn, disabledAccountId } = this.context.identity;

    const explorer = (showTrends ? (
      <ColumnLink transparent to='/explore' icon='hashtag' text={intl.formatMessage(messages.explore)} />
    ) : (
      <ColumnLink transparent to='/search' icon='search' text={intl.formatMessage(messages.search)} />
    ));

    return (
      <div className='navigation-panel'>
        <div className='navigation-panel__logo'>
          <Link to='/' className='column-link column-link--logo'><WordmarkLogo /></Link>
          <hr />
        </div>

        {signedIn && (
          <>
            <ColumnLink transparent to='/notifications' icon={<NotificationsCounterIcon className='column-link__icon' />} text={intl.formatMessage(messages.notifications)} />
            <ColumnLink transparent to='/home' icon='home' text={intl.formatMessage(messages.home)} />
          </>
        )}

        {!signedIn && explorer}

        {(signedIn || timelinePreview) && (
          <>
            <ColumnLink transparent to='/public/local' icon='users' text={intl.formatMessage(messages.local)} />
            <ColumnLink transparent exact to='/public' icon='globe' text={intl.formatMessage(messages.federated)} />
          </>
        )}

        {signedIn && (
          <>
            <ListPanel />
            <hr />
          </>
        )}

        {signedIn && (
          <>
            <FollowRequestsColumnLink />
            <ColumnLink transparent to='/conversations' icon='at' text={intl.formatMessage(messages.direct)} />
          </>
        )}

        {signedIn && explorer}

        {signedIn && (
          <>
            <ColumnLink transparent to='/bookmarks' icon='bookmark' text={intl.formatMessage(messages.bookmarks)} />
            <ColumnLink transparent to='/favourites' icon='star' text={intl.formatMessage(messages.favourites)} />
            <ColumnLink transparent to='/lists' icon='list-ul' text={intl.formatMessage(messages.lists)} />
            <hr />

            <ColumnLink transparent href='/settings/preferences' icon='cog' text={intl.formatMessage(messages.preferences)} />
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
          <ColumnLink transparent to='/about' icon='ellipsis-h' text={intl.formatMessage(messages.about)} />
        </div>

        <NavigationPortal />
      </div>
    );
  }

}

export default injectIntl(NavigationPanel);
