import PropTypes from 'prop-types';

import { FormattedMessage } from 'react-intl';

import { connect } from 'react-redux';

import { me } from 'mastodon/initial_state';
import { HASHTAG_PATTERN_REGEX } from 'mastodon/utils/hashtags';
import { MENTION_PATTERN_REGEX } from 'mastodon/utils/mentions';

import Warning from '../components/warning';

const mapStateToProps = state => ({
  needsLockWarning: state.getIn(['compose', 'privacy']) === 'private' && !state.getIn(['accounts', me, 'locked']),
  hashtagWarning: !['public', 'public_unlisted', 'login'].includes(state.getIn(['compose', 'privacy'])) && state.getIn(['compose', 'searchability']) !== 'public' && HASHTAG_PATTERN_REGEX.test(state.getIn(['compose', 'text'])),
  directMessageWarning: state.getIn(['compose', 'privacy']) === 'direct',
  searchabilityWarning: state.getIn(['compose', 'searchability']) === 'limited',
  mentionWarning: ['mutual', 'circle', 'limited'].includes(state.getIn(['compose', 'privacy'])) && MENTION_PATTERN_REGEX.test(state.getIn(['compose', 'text'])),
  limitedPostWarning: ['mutual', 'circle'].includes(state.getIn(['compose', 'privacy'])) && !state.getIn(['compose', 'limited_scope']),
});

const WarningWrapper = ({ needsLockWarning, hashtagWarning, directMessageWarning, searchabilityWarning, mentionWarning, limitedPostWarning }) => {
  if (needsLockWarning) {
    return <Warning message={<FormattedMessage id='compose_form.lock_disclaimer' defaultMessage='Your account is not {locked}. Anyone can follow you to view your follower-only posts.' values={{ locked: <a href='/settings/profile'><FormattedMessage id='compose_form.lock_disclaimer.lock' defaultMessage='locked' /></a> }} />} />;
  }

  if (hashtagWarning) {
    return <Warning message={<FormattedMessage id='compose_form.hashtag_warning' defaultMessage="This post won't be listed under any hashtag as it is unlisted. Only public posts can be searched by hashtag." />} />;
  }

  if (directMessageWarning) {
    const message = (
      <span>
        <FormattedMessage id='compose_form.encryption_warning' defaultMessage='Posts on Mastodon are not end-to-end encrypted. Do not share any dangerous information over Mastodon.' /> <a href='/terms' target='_blank'><FormattedMessage id='compose_form.direct_message_warning_learn_more' defaultMessage='Learn more' /></a>
      </span>
    );

    return <Warning message={message} />;
  }

  if (searchabilityWarning) {
    return <Warning message={<FormattedMessage id='compose_form.searchability_warning' defaultMessage='Self only searchability is not available other mastodon servers. Others can search your post.' />} />;
  }

  if (mentionWarning) {
    return <Warning message={<FormattedMessage id='compose_form.mention_warning' defaultMessage='When you add a mention to a limited post, the person you are mentioning can also see this post.' />} />;
  }

  if (limitedPostWarning) {
    return <Warning message={<FormattedMessage id='compose_form.limited_post_warning' defaultMessage='Limited posts are NOT reached Misskey, normal Mastodon or so on.' />} />;
  }

  return null;
};

WarningWrapper.propTypes = {
  needsLockWarning: PropTypes.bool,
  hashtagWarning: PropTypes.bool,
  directMessageWarning: PropTypes.bool,
  searchabilityWarning: PropTypes.bool,
  mentionWarning: PropTypes.bool,
  limitedPostWarning: PropTypes.bool,
};

export default connect(mapStateToProps)(WarningWrapper);
