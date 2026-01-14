import { FormattedMessage } from 'react-intl';

import { createSelector } from '@reduxjs/toolkit';

import { animated, useSpring } from '@react-spring/web';

import { me } from 'mastodon/initial_state';
import { useAppSelector } from 'mastodon/store';
import type { RootState } from 'mastodon/store';
import { HASHTAG_PATTERN_REGEX } from 'mastodon/utils/hashtags';
import { MENTION_PATTERN_REGEX } from 'mastodon/utils/mentions';

const selector = createSelector(
  (state: RootState) => state.compose.get('privacy') as string,
  (state: RootState) => !!state.accounts.getIn([me, 'locked']),
  (state: RootState) => state.compose.get('text') as string,
  (state: RootState) => state.compose.get('searchability') as string,
  (state: RootState) => state.compose.get('limited_scope') as string,
  (privacy, locked, text, searchability, limited_scope) => ({
    needsLockWarning: privacy === 'private' && !locked,
    hashtagWarning:
      !['public', 'public_unlisted', 'login'].includes(privacy) &&
      (privacy !== 'unlisted' || searchability !== 'public') &&
      HASHTAG_PATTERN_REGEX.test(text),
    directMessageWarning: privacy === 'direct',
    searchabilityWarning: searchability === 'limited',
    mentionWarning:
      ['mutual', 'circle', 'limited'].includes(privacy) &&
      MENTION_PATTERN_REGEX.test(text),
    limitedPostWarning:
      ['mutual', 'circle'].includes(privacy) && !limited_scope,
  }),
);

export const Warning = () => {
  const {
    needsLockWarning,
    hashtagWarning,
    directMessageWarning,
    searchabilityWarning,
    mentionWarning,
    limitedPostWarning,
  } = useAppSelector(selector);
  if (needsLockWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.lock_disclaimer'
          defaultMessage='Your account is not {locked}. Anyone can follow you to view your follower-only posts.'
          values={{
            locked: (
              <a href='/settings/privacy#account_unlocked'>
                <FormattedMessage
                  id='compose_form.lock_disclaimer.lock'
                  defaultMessage='locked'
                />
              </a>
            ),
          }}
        />
      </WarningMessage>
    );
  }

  if (hashtagWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.hashtag_warning'
          defaultMessage="This post won't be listed under any hashtag as it is unlisted. Only public posts can be searched by hashtag."
        />
      </WarningMessage>
    );
  }

  if (directMessageWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.encryption_warning'
          defaultMessage='Posts on Mastodon are not end-to-end encrypted. Do not share any dangerous information over Mastodon.'
        />{' '}
        <a href='/terms' target='_blank'>
          <FormattedMessage
            id='compose_form.direct_message_warning_learn_more'
            defaultMessage='Learn more'
          />
        </a>
      </WarningMessage>
    );
  }

  if (searchabilityWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.searchability_warning'
          defaultMessage='Self only searchability is not available other mastodon servers. Others can search your post.'
        />
      </WarningMessage>
    );
  }

  if (mentionWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.mention_warning'
          defaultMessage='When you add a mention to a limited post, the person you are mentioning can also see this post.'
        />
      </WarningMessage>
    );
  }

  if (limitedPostWarning) {
    return (
      <WarningMessage>
        <FormattedMessage
          id='compose_form.limited_post_warning'
          defaultMessage='Limited posts are NOT reached Misskey, normal Mastodon or so on.'
        />
      </WarningMessage>
    );
  }

  return null;
};

export const WarningMessage: React.FC<React.PropsWithChildren> = ({
  children,
}) => {
  const styles = useSpring({
    from: {
      opacity: 0,
      transform: 'scale(0.85, 0.75)',
    },
    to: {
      opacity: 1,
      transform: 'scale(1, 1)',
    },
  });
  return (
    <animated.div className='compose-form__warning' style={styles}>
      {children}
    </animated.div>
  );
};
