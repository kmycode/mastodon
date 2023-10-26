import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';


import { ReactComponent as CircleIcon } from '@material-symbols/svg-600/outlined/account_circle.svg';
import { ReactComponent as AlternateEmailIcon } from '@material-symbols/svg-600/outlined/alternate_email.svg';
import { ReactComponent as PublicUnlistedIcon } from '@material-symbols/svg-600/outlined/cloud.svg';
import { ReactComponent as MutualIcon } from '@material-symbols/svg-600/outlined/compare_arrows.svg';
import { ReactComponent as LoginIcon } from '@material-symbols/svg-600/outlined/key.svg';
import { ReactComponent as LockIcon } from '@material-symbols/svg-600/outlined/lock.svg';
import { ReactComponent as LockOpenIcon } from '@material-symbols/svg-600/outlined/lock_open.svg';
import { ReactComponent as PublicIcon } from '@material-symbols/svg-600/outlined/public.svg';
import { supportsPassiveEvents } from 'detect-passive-events';
import Overlay from 'react-overlays/Overlay';


import { Icon }  from 'mastodon/components/icon';
import { enableLoginPrivacy, enableLocalPrivacy } from 'mastodon/initial_state';

import { IconButton } from '../../../components/icon_button';

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  public_long: { id: 'privacy.public.long', defaultMessage: 'Visible for all' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Unlisted' },
  unlisted_long: { id: 'privacy.unlisted.long', defaultMessage: 'Visible for all, but opted-out of discovery features' },
  public_unlisted_short: { id: 'privacy.public_unlisted.short', defaultMessage: 'Public unlisted' },
  public_unlisted_long: { id: 'privacy.public_unlisted.long', defaultMessage: 'Visible for all without GTL' },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  login_long: { id: 'privacy.login.long', defaultMessage: 'Login user only' },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers only' },
  private_long: { id: 'privacy.private.long', defaultMessage: 'Visible for followers only' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual' },
  mutual_long: { id: 'privacy.mutual.long', defaultMessage: 'Mutual follows only' },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle' },
  circle_long: { id: 'privacy.circle.long', defaultMessage: 'Circle members only' },
  direct_short: { id: 'privacy.direct.short', defaultMessage: 'Mentioned people only' },
  direct_long: { id: 'privacy.direct.long', defaultMessage: 'Visible for mentioned users only' },
  change_privacy: { id: 'privacy.change', defaultMessage: 'Adjust status privacy' },
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
      { icon: 'unlock', iconComponent: LockOpenIcon, value: 'unlisted', text: formatMessage(messages.unlisted_short), meta: formatMessage(messages.unlisted_long) },
      { icon: 'lock', iconComponent: LockIcon, value: 'private', text: formatMessage(messages.private_short), meta: formatMessage(messages.private_long) },
      { icon: 'exchange', iconComponent: MutualIcon, value: 'mutual', text: formatMessage(messages.mutual_short), meta: formatMessage(messages.mutual_long) },
      { icon: 'user-circle', iconComponent: CircleIcon, value: 'circle', text: formatMessage(messages.circle_short), meta: formatMessage(messages.circle_long) },
    ];
    this.selectableOptions = [...this.options];

    if (!enableLoginPrivacy) {
      this.selectableOptions = this.selectableOptions.filter((opt) => opt.value !== 'login');
    }

    if (!enableLocalPrivacy) {
      this.selectableOptions = this.selectableOptions.filter((opt) => opt.value !== 'public_unlisted');
    }

    if (!this.props.noDirect) {
      this.options.push(
        { icon: 'at', iconComponent: AlternateEmailIcon, value: 'direct', text: formatMessage(messages.direct_short), meta: formatMessage(messages.direct_long) },
      );
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
    const { value, container, disabled, intl } = this.props;
    const { open, placement } = this.state;

    const valueOption = this.options.find(item => item.value === value) || this.options[0];

    return (
      <div ref={this.setTargetRef} onKeyDown={this.handleKeyDown}>
        <IconButton
          className='privacy-dropdown__value-icon'
          icon={valueOption.icon}
          iconComponent={valueOption.iconComponent}
          title={intl.formatMessage(messages.change_privacy)}
          size={18}
          expanded={open}
          active={open}
          inverted
          onClick={this.handleToggle}
          onMouseDown={this.handleMouseDown}
          onKeyDown={this.handleButtonKeyDown}
          style={{ height: null, lineHeight: '27px' }}
          disabled={disabled}
        />

        <Overlay show={open} placement={placement} flip target={this.findTarget} container={container} popperConfig={{ strategy: 'fixed', onFirstUpdate: this.handleOverlayEnter }}>
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
