import PropTypes from 'prop-types';
import { useState, useRef, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';


import classNames from 'classnames';

import Overlay from 'react-overlays/Overlay';

import BadgeIcon from '@/material-icons/400-24px/badge.svg?react';
import { Button } from 'mastodon/components/button';
import { Icon } from 'mastodon/components/icon';

export const BlueskyPill = ({ domain, username, isSelf }) => {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef(null);

  const handleClick = useCallback(() => {
    setOpen(!open);
  }, [open, setOpen]);

  const handleBlueskyProfileOpenClick = useCallback(() => {
    window.open(`https://bsky.app/profile/${replacedUsername}.${replacedDomain}.ap.brid.gy`, '_blank');
  });

  const replacedUsername = username.replaceAll('_', '-');
  const replacedDomain = domain.replaceAll('_', '-');

  return (
    <>
      <button className={classNames('account__domain-pill', { active: open })} ref={triggerRef} onClick={handleClick}>bluesky</button>

      <Overlay show={open} rootClose onHide={handleClick} offset={[5, 5]} target={triggerRef}>
        {({ props }) => (
          <div {...props} className='account__domain-pill__popout dropdown-animation'>
            <div className='account__domain-pill__popout__header'>
              <div className='account__domain-pill__popout__header__icon'><Icon icon={BadgeIcon} /></div>
              <h3><FormattedMessage id='bluesky_pill.account_available' defaultMessage='Bluesky account is available' /></h3>
            </div>

            <div className='account__domain-pill__popout__handle'>
              <div className='account__domain-pill__popout__handle__label'>{isSelf ? <FormattedMessage id='bluesky_pill.your_handle' defaultMessage='Your bluesky account:' /> : <FormattedMessage id='bluesky_pill.their_handle' defaultMessage='Their bluesky account:' />}</div>
              <div className='account__domain-pill__popout__handle__handle'>@{replacedUsername}.{replacedDomain}.ap.brid.gy</div>
            </div>

            <p>{isSelf ? <FormattedMessage id='bluesky_pill.who_you_are' defaultMessage='You can share your Mastodon account from Bluesky using the above user ID. However, please note that this is actually a bridge connection and there are many restrictions, such as only public posts will be shared.' /> : <FormattedMessage id='bluesky_pill.who_they_are' defaultMessage='You can follow this Mastodon account from Bluesky using the above user ID. However, please note that this is actually a bridge connection and there are many restrictions, such as only public posts will be shared.' />}</p>

            <p><Button onClick={handleBlueskyProfileOpenClick}><FormattedMessage id='bluesky_pill.jump_bluesky_profile' defaultMessage='Jump Bluesky profile page' /></Button></p>
          </div>
        )}
      </Overlay>
    </>
  );
};

BlueskyPill.propTypes = {
  username: PropTypes.string.isRequired,
  domain: PropTypes.string.isRequired,
  isSelf: PropTypes.bool,
};
