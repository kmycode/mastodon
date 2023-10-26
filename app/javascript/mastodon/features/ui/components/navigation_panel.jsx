import PropTypes from 'prop-types';
import { Component } from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import { WordmarkLogo } from 'mastodon/components/logo';
import { NavigationPortal } from 'mastodon/components/navigation_portal';
import { enableDtlMenu, timelinePreview, trendsEnabled, dtlTag } from 'mastodon/initial_state';
import { transientSingleColumn } from 'mastodon/is_mobile';

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
  followsAndFollowers: { id: 'navigation_bar.follows_and_followers', defaultMessage: 'Follows and followers' },
  about: { id: 'navigation_bar.about', defaultMessage: 'About' },
  search: { id: 'navigation_bar.search', defaultMessage: 'Search' },
  advancedInterface: { id: 'navigation_bar.advanced_interface', defaultMessage: 'Open in advanced web interface' },
  openedInClassicInterface: { id: 'navigation_bar.opened_in_classic_interface', defaultMessage: 'Posts, accounts, and other specific pages are opened by default in the classic web interface.' },
});

class NavigationPanel extends Component {

  static contextTypes = {
    identity: PropTypes.object.isRequired,
  };

  static propTypes = {
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
    const { signedIn, disabledAccountId } = this.context.identity;

    const explorer = (trendsEnabled ? (
      <ColumnLink transparent to='/explore' icon='hashtag' text={intl.formatMessage(messages.explore)} />
    ) : (
      <ColumnLink transparent to='/search' icon='search' text={intl.formatMessage(messages.search)} />
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
          {!banner && <hr />}
        </div>

        {banner &&
          <div class='navigation-panel__banner'>
            {banner}
          </div>
        }

        {signedIn && (
          <>
            <ColumnLink transparent to='/home' icon='home' text={intl.formatMessage(messages.home)} />
            <ColumnLink transparent to='/notifications' icon={<NotificationsCounterIcon className='column-link__icon' />} text={intl.formatMessage(messages.notifications)} />
            <ColumnLink transparent to='/public/local/fixed' icon='users' text={intl.formatMessage(messages.local)} />
          </>
        )}

        {signedIn && enableDtlMenu && dtlTag && (
          <ColumnLink transparent to={`/tags/${dtlTag}`} icon='users' text={intl.formatMessage(messages.deepLocal)} />
        )}

        {!signedIn && explorer}

        {signedIn && (
          <ColumnLink transparent to='/public' isActive={this.isFirehoseActive} icon='globe' text={intl.formatMessage(messages.firehose)} />
        )}

        {(!signedIn && timelinePreview) && (
          <ColumnLink transparent to='/public/local' isActive={this.isFirehoseActive} icon='globe' text={intl.formatMessage(messages.firehose)} />
        )}

        {signedIn && (
          <>
            <ListPanel />
            <hr />
          </>
        )}

        {signedIn && (
          <>
            <ColumnLink transparent to='/lists' icon='list-ul' text={intl.formatMessage(messages.lists)} />
            <ColumnLink transparent to='/antennasw' icon='wifi' text={intl.formatMessage(messages.antennas)} isActive={this.isAntennasActive} />
            <ColumnLink transparent to='/circles' icon='user-circle' text={intl.formatMessage(messages.circles)} />
            <FollowRequestsColumnLink />
            <ColumnLink transparent to='/conversations' icon='at' text={intl.formatMessage(messages.direct)} />
          </>
        )}

        {signedIn && explorer}

        {signedIn && (
          <>
            <ColumnLink transparent to='/bookmark_categories' icon='bookmark' text={intl.formatMessage(messages.bookmarks)} />
            <ColumnLink transparent to='/favourites' icon='star' text={intl.formatMessage(messages.favourites)} />
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
