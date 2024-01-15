import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import { supportsPassiveEvents } from 'detect-passive-events';
import Overlay from 'react-overlays/Overlay';

import AlternateEmailIcon from 'mastodon/../material-icons/400-24px/alternate_email.svg?react';
import PublicUnlistedIcon from 'mastodon/../material-icons/400-24px/cloud.svg?react';
import LockIcon from 'mastodon/../material-icons/400-24px/lock.svg?react';
import LockOpenIcon from 'mastodon/../material-icons/400-24px/no_encryption.svg?react';
import PublicIcon from 'mastodon/../material-icons/400-24px/public.svg?react';
import SearchIcon from 'mastodon/../material-icons/400-24px/search.svg?react';
import { Icon }  from 'mastodon/components/icon';
import { enableLocalPrivacy } from 'mastodon/initial_state';

import { IconButton } from '../../../components/icon_button';


const messages = defineMessages({
  public_short: { id: 'searchability.public.short', defaultMessage: 'Public' },
  public_long: { id: 'searchability.public.long', defaultMessage: 'Anyone can find' },
  public_unlisted_short: { id: 'searchability.public_unlisted.short', defaultMessage: 'Public unlisted' },
  public_unlisted_long: { id: 'searchability.public_unlisted.long', defaultMessage: 'Local users and followers can find' },
  private_short: { id: 'searchability.unlisted.short', defaultMessage: 'Followers' },
  private_long: { id: 'searchability.unlisted.long', defaultMessage: 'Your followers can find' },
  direct_short: { id: 'searchability.private.short', defaultMessage: 'Reactionners' },
  direct_long: { id: 'searchability.private.long', defaultMessage: 'Reacter of this post can find' },
  limited_short: { id: 'searchability.direct.short', defaultMessage: 'Self only' },
  limited_long: { id: 'searchability.direct.long', defaultMessage: 'Nobody can find, but you can' },
  change_searchability: { id: 'searchability.change', defaultMessage: 'Set status searchability' },
});

const listenerOptions = supportsPassiveEvents ? { passive: true, capture: true } : true;

class SearchabilityDropdownMenu extends PureComponent {

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
          <div role='option' tabIndex='0' key={item.value} data-index={item.value} onKeyDown={this.handleKeyDown} onClick={this.handleClick} className={classNames('privacy-dropdown__option', { active: item.value === value })} aria-selected={item.value === value} ref={item.value === value ? this.setFocusRef : null}>
            <div className='privacy-dropdown__option__icon'>
              <Icon id={item.icon} icon={item.iconComponent} fixedWidth />
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

class SearchabilityDropdown extends PureComponent {

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
      { icon: 'unlock', iconComponent: LockOpenIcon, value: 'private', text: formatMessage(messages.private_short), meta: formatMessage(messages.private_long) },
      { icon: 'lock', iconComponent: LockIcon, value: 'direct', text: formatMessage(messages.direct_short), meta: formatMessage(messages.direct_long) },
      { icon: 'at', iconComponent: AlternateEmailIcon, value: 'limited', text: formatMessage(messages.limited_short), meta: formatMessage(messages.limited_long) },
    ];

    if (!enableLocalPrivacy) {
      this.options = this.options.filter((opt) => opt.value !== 'public_unlisted');
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

    const valueOption = this.options.find(item => item.value === value);

    return (
      <div className={classNames('privacy-dropdown', placement, { active: open })} onKeyDown={this.handleKeyDown}>
        <div className={classNames('privacy-dropdown__value', 'searchability', { active: this.options.indexOf(valueOption) === (placement === 'bottom' ? 0 : (this.options.length - 1)) })} ref={this.setTargetRef}>
          <IconButton
            className='privacy-dropdown__value-icon'
            icon={valueOption.icon}
            iconComponent={valueOption.iconComponent}
            title={intl.formatMessage(messages.change_searchability)}
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
          <Icon
            className='searchability-dropdown__value-overlay'
            id='search'
            icon={SearchIcon}
          />
        </div>

        <Overlay show={open} placement={'bottom'} flip target={this.findTarget} container={container} popperConfig={{ strategy: 'fixed', onFirstUpdate: this.handleOverlayEnter }}>
          {({ props, placement }) => (
            <div {...props}>
              <div className={`dropdown-animation privacy-dropdown__dropdown ${placement}`}>
                <SearchabilityDropdownMenu
                  items={this.options}
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

export default injectIntl(SearchabilityDropdown);
