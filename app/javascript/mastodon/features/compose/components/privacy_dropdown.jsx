import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import { supportsPassiveEvents } from 'detect-passive-events';
import Overlay from 'react-overlays/Overlay';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import AlternateEmailIcon from '@/material-icons/400-24px/alternate_email.svg?react';
import PublicUnlistedIcon from '@/material-icons/400-24px/cloud.svg?react';
import MutualIcon from '@/material-icons/400-24px/compare_arrows.svg?react';
import InfoIcon from '@/material-icons/400-24px/info.svg?react';
import LoginIcon from '@/material-icons/400-24px/key.svg?react';
import LockIcon from '@/material-icons/400-24px/lock.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import QuietTimeIcon from '@/material-icons/400-24px/quiet_time.svg?react';
import ReplyIcon from '@/material-icons/400-24px/reply.svg?react';
import LimitedIcon from '@/material-icons/400-24px/shield.svg?react';
import { Icon }  from 'mastodon/components/icon';
import { enableLoginPrivacy, enableLocalPrivacy } from 'mastodon/initial_state';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_long: { id: 'privacy.public.long', defaultMessage: 'Anyone on and off Mastodon' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Quiet public' },
  unlisted_long: { id: 'privacy.unlisted.long', defaultMessage: 'Fewer algorithmic fanfares' },
  public_unlisted_short: { id: 'privacy.public_unlisted.short', defaultMessage: 'Public unlisted' },
  public_unlisted_long: { id: 'privacy.public_unlisted.long', defaultMessage: 'Visible for all without GTL' },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  login_long: { id: 'privacy.login.long', defaultMessage: 'Login user only' },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers' },
  private_long: { id: 'privacy.private.long', defaultMessage: 'Only your followers' },
  limited_short: { id: 'privacy.limited.short', defaultMessage: 'Limited' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual' },
  mutual_long: { id: 'privacy.mutual.long', defaultMessage: 'Mutual follows only' },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle' },
  circle_long: { id: 'privacy.circle.long', defaultMessage: 'Circle members only' },
  reply_short: { id: 'privacy.reply.short', defaultMessage: 'Reply' },
  reply_long: { id: 'privacy.reply.long', defaultMessage: 'Reply to limited post' },
  direct_short: { id: 'privacy.direct.short', defaultMessage: 'Specific people' },
  direct_long: { id: 'privacy.direct.long', defaultMessage: 'Everyone mentioned in the post' },
  change_privacy: { id: 'privacy.change', defaultMessage: 'Change post privacy' },
  unlisted_extra: { id: 'privacy.unlisted.additional', defaultMessage: 'This behaves exactly like public, except the post will not appear in live feeds or hashtags, explore, or Mastodon search, even if you are opted-in account-wide.' },
});

const listenerOptions = supportsPassiveEvents ? { passive: true, capture: true } : true;

class PrivacyDropdownMenu extends PureComponent {

  static propTypes = {
    style: PropTypes.object,
    items: PropTypes.array.isRequired,
    value: PropTypes.string.isRequired,
    onClose: PropTypes.func.isRequired,
    onChange: PropTypes.func.isRequired,
  };

  handleDocumentClick = e => {
    if (this.node && !this.node.contains(e.target)) {
      this.props.onClose();
      e.stopPropagation();
    }
  };

  handleKeyDown = e => {
    const { items } = this.props;
    const value = e.currentTarget.getAttribute('data-index');
    const index = items.findIndex(item => {
      return (item.value === value);
    });
    let element = null;

    switch(e.key) {
    case 'Escape':
      this.props.onClose();
      break;
    case 'Enter':
      this.handleClick(e);
      break;
    case 'ArrowDown':
      element = this.node.childNodes[index + 1] || this.node.firstChild;
      break;
    case 'ArrowUp':
      element = this.node.childNodes[index - 1] || this.node.lastChild;
      break;
    case 'Tab':
      if (e.shiftKey) {
        element = this.node.childNodes[index - 1] || this.node.lastChild;
      } else {
        element = this.node.childNodes[index + 1] || this.node.firstChild;
      }
      break;
    case 'Home':
      element = this.node.firstChild;
      break;
    case 'End':
      element = this.node.lastChild;
      break;
    }

    if (element) {
      element.focus();
      this.props.onChange(element.getAttribute('data-index'));
      e.preventDefault();
      e.stopPropagation();
    }
  };

  handleClick = e => {
    const value = e.currentTarget.getAttribute('data-index');

    e.preventDefault();

    this.props.onClose();
    this.props.onChange(value);
  };

  componentDidMount () {
    document.addEventListener('click', this.handleDocumentClick, { capture: true });
    document.addEventListener('touchend', this.handleDocumentClick, listenerOptions);
    if (this.focusedItem) this.focusedItem.focus({ preventScroll: true });
  }

  componentWillUnmount () {
    document.removeEventListener('click', this.handleDocumentClick, { capture: true });
    document.removeEventListener('touchend', this.handleDocumentClick, listenerOptions);
  }

  setRef = c => {
    this.node = c;
  };

  setFocusRef = c => {
    this.focusedItem = c;
  };
  
  render () {
    const { style, items, value } = this.props;

    return (
      <div style={{ ...style }} role='listbox' ref={this.setRef}>
        {items.map(item => (
          <div role='option' tabIndex={0} key={item.value} data-index={item.value} onKeyDown={this.handleKeyDown} onClick={this.handleClick} className={classNames('privacy-dropdown__option', { active: item.value === value })} aria-selected={item.value === value} ref={item.value === value ? this.setFocusRef : null}>
            <div className='privacy-dropdown__option__icon'>
              <Icon id={item.icon} icon={item.iconComponent} />
            </div>

            <div className='privacy-dropdown__option__content'>
              <strong>{item.text}</strong>
              {item.meta}
            </div>

            {item.extra && (
              <div className='privacy-dropdown__option__additional' title={item.extra}>
                <Icon id='info-circle' icon={item.extraIcomComponent ?? InfoIcon} />
              </div>
            )}
          </div>
        ))}
      </div>
    );
  }

}

class PrivacyDropdown extends PureComponent {

  static propTypes = {
    isUserTouching: PropTypes.func,
    onModalOpen: PropTypes.func,
    onModalClose: PropTypes.func,
    value: PropTypes.string.isRequired,
    onChange: PropTypes.func.isRequired,
    noDirect: PropTypes.bool,
    noLimited: PropTypes.bool,
    replyToLimited: PropTypes.bool,
    container: PropTypes.func,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  };

  state = {
    open: false,
    placement: 'bottom',
  };

  handleToggle = () => {
    if (this.props.isUserTouching && this.props.isUserTouching()) {
      if (this.state.open) {
        this.props.onModalClose();
      } else {
        this.props.onModalOpen({
          actions: this.options.map(option => ({ ...option, active: option.value === this.props.value })),
          onClick: this.handleModalActionClick,
        });
      }
    } else {
      if (this.state.open && this.activeElement) {
        this.activeElement.focus({ preventScroll: true });
      }
      this.setState({ open: !this.state.open });
    }
  };

  handleModalActionClick = (e) => {
    e.preventDefault();

    const { value } = this.options[e.currentTarget.getAttribute('data-index')];

    this.props.onModalClose();
    this.props.onChange(value);
  };

  handleKeyDown = e => {
    switch(e.key) {
    case 'Escape':
      this.handleClose();
      break;
    }
  };

  handleMouseDown = () => {
    if (!this.state.open) {
      this.activeElement = document.activeElement;
    }
  };

  handleButtonKeyDown = (e) => {
    switch(e.key) {
    case ' ':
    case 'Enter':
      this.handleMouseDown();
      break;
    }
  };

  handleClose = () => {
    if (this.state.open && this.activeElement) {
      this.activeElement.focus({ preventScroll: true });
    }
    this.setState({ open: false });
  };

  handleChange = value => {
    this.props.onChange(value);
  };

  UNSAFE_componentWillMount () {
    const { intl: { formatMessage } } = this.props;

    this.options = [
      { icon: 'globe', iconComponent: PublicIcon, value: 'public', text: formatMessage(messages.public_short), meta: formatMessage(messages.public_long) },
      { icon: 'cloud', iconComponent: PublicUnlistedIcon, value: 'public_unlisted', text: formatMessage(messages.public_unlisted_short), meta: formatMessage(messages.public_unlisted_long) },
      { icon: 'key', iconComponent: LoginIcon, value: 'login', text: formatMessage(messages.login_short), meta: formatMessage(messages.login_long) },
      { icon: 'unlock', iconComponent: QuietTimeIcon,  value: 'unlisted', text: formatMessage(messages.unlisted_short), meta: formatMessage(messages.unlisted_long), extra: formatMessage(messages.unlisted_extra) },
      { icon: 'lock', iconComponent: LockIcon, value: 'private', text: formatMessage(messages.private_short), meta: formatMessage(messages.private_long) },
      { icon: 'exchange', iconComponent: MutualIcon, value: 'mutual', text: formatMessage(messages.mutual_short), meta: formatMessage(messages.mutual_long), extra: formatMessage(messages.limited_short), extraIcomComponent: LimitedIcon },
      { icon: 'user-circle', iconComponent: CircleIcon, value: 'circle', text: formatMessage(messages.circle_short), meta: formatMessage(messages.circle_long), extra: formatMessage(messages.limited_short), extraIcomComponent: LimitedIcon },
    ];

    if (!this.props.noDirect) {
      this.options.push(
        { icon: 'at', iconComponent: AlternateEmailIcon, value: 'direct', text: formatMessage(messages.direct_short), meta: formatMessage(messages.direct_long) },
      );
    }

    if (this.props.noLimited) {
      this.options = this.options.filter((opt) => !['mutual', 'circle'].includes(opt.value));
    }

    this.selectableOptions = [...this.options];

    if (!enableLoginPrivacy) {
      this.selectableOptions = this.selectableOptions.filter((opt) => opt.value !== 'login');
    }

    if (!enableLocalPrivacy) {
      this.selectableOptions = this.selectableOptions.filter((opt) => opt.value !== 'public_unlisted');
    }
  }

  setTargetRef = c => {
    this.target = c;
  };

  findTarget = () => {
    return this.target;
  };

  handleOverlayEnter = (state) => {
    this.setState({ placement: state.placement });
  };

  render () {
    const { value, container, disabled, intl, replyToLimited } = this.props;
    const { open, placement } = this.state;

    if (replyToLimited) {
      if (!this.selectableOptions.some((op) => op.value === 'reply')) {
        this.selectableOptions.unshift(
          { icon: 'reply', iconComponent: ReplyIcon, value: 'reply', text: intl.formatMessage(messages.reply_short), meta: intl.formatMessage(messages.reply_long), extra: intl.formatMessage(messages.limited_short), extraIcomComponent: LimitedIcon },
        );
      }
    } else {
      if (this.selectableOptions.some((op) => op.value === 'reply')) {
        this.selectableOptions = this.selectableOptions.filter((op) => op.value !== 'reply');
      }
    }

    const valueOption = this.selectableOptions.find(item => item.value === value) || this.selectableOptions[0];

    return (
      <div ref={this.setTargetRef} onKeyDown={this.handleKeyDown}>
        <button
          type='button'
          title={intl.formatMessage(messages.change_privacy)}
          aria-expanded={open}
          onClick={this.handleToggle}
          onMouseDown={this.handleMouseDown}
          onKeyDown={this.handleButtonKeyDown}
          disabled={disabled}
          className={classNames('dropdown-button', { active: open })}
        >
          <Icon id={valueOption.icon} icon={valueOption.iconComponent} />
          <span className='dropdown-button__label'>{valueOption.text}</span>
        </button>

        <Overlay show={open} offset={[5, 5]} placement={placement} flip target={this.findTarget} container={container} popperConfig={{ strategy: 'fixed', onFirstUpdate: this.handleOverlayEnter }}>
          {({ props, placement }) => (
            <div {...props}>
              <div className={`dropdown-animation privacy-dropdown__dropdown ${placement}`}>
                <PrivacyDropdownMenu
                  items={this.selectableOptions}
                  value={value}
                  onClose={this.handleClose}
                  onChange={this.handleChange}
                />
              </div>
            </div>
          )}
        </Overlay>
      </div>
    );
  }

}

export default injectIntl(PrivacyDropdown);
