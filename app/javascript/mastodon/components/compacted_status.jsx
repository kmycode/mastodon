import PropTypes from 'prop-types';

import { injectIntl, defineMessages, FormattedMessage } from 'react-intl';

import classNames from 'classnames';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';

import { HotKeys } from 'react-hotkeys';

import AttachmentList from 'mastodon/components/attachment_list';
import { Icon }  from 'mastodon/components/icon';

import Card from '../features/status/components/card';
// We use the component (and not the container) since we do not want
// to use the progress bar to show download progress
import Bundle from '../features/ui/components/bundle';
import { MediaGallery, Video, Audio } from '../features/ui/util/async-components';
import { displayMedia } from '../initial_state';

import { Avatar } from './avatar';
import { DisplayName } from './display_name';
import { getHashtagBarForStatus } from './hashtag_bar';
import { RelativeTimestamp } from './relative_timestamp';
import StatusContent from './status_content';

const domParser = new DOMParser();

export const textForScreenReader = (intl, status, rebloggedByText = false) => {
  const displayName = status.getIn(['account', 'display_name']);

  const spoilerText = status.getIn(['translation', 'spoiler_text']) || status.get('spoiler_text');
  const contentHtml = status.getIn(['translation', 'contentHtml']) || status.get('contentHtml');
  const contentText = domParser.parseFromString(contentHtml, 'text/html').documentElement.textContent;

  const values = [
    displayName.length === 0 ? status.getIn(['account', 'acct']).split('@')[0] : displayName,
    spoilerText && status.get('hidden') ? spoilerText : contentText,
    intl.formatDate(status.get('created_at'), { hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric' }),
    status.getIn(['account', 'acct']),
  ];

  if (rebloggedByText) {
    values.push(rebloggedByText);
  }

  return values.join(', ');
};

export const defaultMediaVisibility = (status) => {
  if (!status) {
    return undefined;
  }

  if (status.get('reblog', null) !== null && typeof status.get('reblog') === 'object') {
    status = status.get('reblog');
  }

  return (displayMedia !== 'hide_all' && !status.get('sensitive') || displayMedia === 'show_all');
};

const messages = defineMessages({
  public_short: { id: 'privacy.public.short', defaultMessage: 'Public' },
  unlisted_short: { id: 'privacy.unlisted.short', defaultMessage: 'Unlisted' },
  public_unlisted_short: { id: 'privacy.public_unlisted.short', defaultMessage: 'Public unlisted' },
  login_short: { id: 'privacy.login.short', defaultMessage: 'Login only' },
  private_short: { id: 'privacy.private.short', defaultMessage: 'Followers only' },
  limited_short: { id: 'privacy.limited.short', defaultMessage: 'Limited menbers only' },
  mutual_short: { id: 'privacy.mutual.short', defaultMessage: 'Mutual followers only' },
  circle_short: { id: 'privacy.circle.short', defaultMessage: 'Circle members only' },
  personal_short: { id: 'privacy.personal.short', defaultMessage: 'Yourself only' },
  direct_short: { id: 'privacy.direct.short', defaultMessage: 'Mentioned people only' },
  edited: { id: 'status.edited', defaultMessage: 'Edited {date}' },
});

class CompactedStatus extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    status: ImmutablePropTypes.map,
    previousId: PropTypes.string,
    nextInReplyToId: PropTypes.string,
    rootId: PropTypes.string,
    onClick: PropTypes.func,
    onOpenMedia: PropTypes.func,
    onOpenVideo: PropTypes.func,
    onHeightChange: PropTypes.func,
    onToggleHidden: PropTypes.func,
    onToggleCollapsed: PropTypes.func,
    onTranslate: PropTypes.func,
    onInteractionModal: PropTypes.func,
    muted: PropTypes.bool,
    hidden: PropTypes.bool,
    unread: PropTypes.bool,
    onMoveUp: PropTypes.func,
    onMoveDown: PropTypes.func,
    showThread: PropTypes.bool,
    getScrollPosition: PropTypes.func,
    updateScrollBottom: PropTypes.func,
    cacheMediaWidth: PropTypes.func,
    cachedMediaWidth: PropTypes.number,
  };

  // Avoid checking props that are functions (and whose equality will always
  // evaluate to false. See react-immutable-pure-component for usage.
  updateOnProps = [
    'status',
    'muted',
    'hidden',
    'unread',
  ];

  state = {
    showMedia: defaultMediaVisibility(this.props.status),
    statusId: undefined,
    forceFilter: undefined,
  };

  static getDerivedStateFromProps(nextProps, prevState) {
    if (nextProps.status && nextProps.status.get('id') !== prevState.statusId) {
      return {
        showMedia: defaultMediaVisibility(nextProps.status),
        statusId: nextProps.status.get('id'),
      };
    } else {
      return null;
    }
  }

  handleToggleMediaVisibility = () => {
    this.setState({ showMedia: !this.state.showMedia });
  };

  handleClick = e => {
    if (e && (e.button !== 0 || e.ctrlKey || e.metaKey)) {
      return;
    }

    if (e) {
      e.preventDefault();
    }

    this.handleHotkeyOpen();
  };

  handlePrependAccountClick = e => {
    this.handleAccountClick(e, false);
  };

  handleAccountClick = (e, proper = true) => {
    if (e && (e.button !== 0 || e.ctrlKey || e.metaKey))  {
      return;
    }

    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    this._openProfile(proper);
  };

  handleExpandedToggle = () => {
    this.props.onToggleHidden(this._properStatus());
  };

  handleCollapsedToggle = isCollapsed => {
    this.props.onToggleCollapsed(this._properStatus(), isCollapsed);
  };

  handleTranslate = () => {
    this.props.onTranslate(this._properStatus());
  };

  getAttachmentAspectRatio () {
    const attachments = this._properStatus().get('media_attachments');

    if (attachments.getIn([0, 'type']) === 'video') {
      return `${attachments.getIn([0, 'meta', 'original', 'width'])} / ${attachments.getIn([0, 'meta', 'original', 'height'])}`;
    } else if (attachments.getIn([0, 'type']) === 'audio') {
      return '16 / 9';
    } else {
      return (attachments.size === 1 && attachments.getIn([0, 'meta', 'small', 'aspect'])) ? attachments.getIn([0, 'meta', 'small', 'aspect']) : '3 / 2'
    }
  }

  renderLoadingMediaGallery = () => {
    return (
      <div className='media-gallery' style={{ aspectRatio: this.getAttachmentAspectRatio() }} />
    );
  };

  renderLoadingVideoPlayer = () => {
    return (
      <div className='video-player' style={{ aspectRatio: this.getAttachmentAspectRatio() }} />
    );
  };

  renderLoadingAudioPlayer = () => {
    return (
      <div className='audio-player' style={{ aspectRatio: this.getAttachmentAspectRatio() }} />
    );
  };

  handleOpenVideo = (options) => {
    const status = this._properStatus();
    const lang = status.getIn(['translation', 'language']) || status.get('language');
    this.props.onOpenVideo(status.get('id'), status.getIn(['media_attachments', 0]), lang, options);
  };

  handleOpenMedia = (media, index) => {
    const status = this._properStatus();
    const lang = status.getIn(['translation', 'language']) || status.get('language');
    this.props.onOpenMedia(status.get('id'), media, index, lang);
  };

  handleHotkeyOpenMedia = e => {
    const { onOpenMedia, onOpenVideo } = this.props;
    const status = this._properStatus();

    e.preventDefault();

    if (status.get('media_attachments').size > 0) {
      const lang = status.getIn(['translation', 'language']) || status.get('language');
      if (status.getIn(['media_attachments', 0, 'type']) === 'video') {
        onOpenVideo(status.get('id'), status.getIn(['media_attachments', 0]), lang, { startTime: 0 });
      } else {
        onOpenMedia(status.get('id'), status.get('media_attachments'), 0, lang);
      }
    }
  };

  handleHotkeyOpen = () => {
    if (this.props.onClick) {
      this.props.onClick();
      return;
    }

    const { router } = this.context;
    const status = this._properStatus();

    if (!router) {
      return;
    }

    router.history.push(`/@${status.getIn(['account', 'acct'])}/${status.get('id')}`);
  };

  handleHotkeyOpenProfile = () => {
    this._openProfile();
  };

  _openProfile = (proper = true) => {
    const { router } = this.context;
    const status = proper ? this._properStatus() : this.props.status;

    if (!router) {
      return;
    }

    router.history.push(`/@${status.getIn(['account', 'acct'])}`);
  };

  handleHotkeyMoveUp = e => {
    this.props.onMoveUp(this.props.status.get('id'), e.target.getAttribute('data-featured'));
  };

  handleHotkeyMoveDown = e => {
    this.props.onMoveDown(this.props.status.get('id'), e.target.getAttribute('data-featured'));
  };

  handleHotkeyToggleHidden = () => {
    this.props.onToggleHidden(this._properStatus());
  };

  handleHotkeyToggleSensitive = () => {
    this.handleToggleMediaVisibility();
  };

  _properStatus () {
    const { status } = this.props;

    if (status.get('reblog', null) !== null && typeof status.get('reblog') === 'object') {
      return status.get('reblog');
    } else {
      return status;
    }
  }

  handleRef = c => {
    this.node = c;
  };

  render () {
    const { intl, hidden, featured, unread, showThread, previousId, nextInReplyToId, rootId } = this.props;

    let { status } = this.props;

    if (status === null) {
      return null;
    }

    const handlers = this.props.muted ? {} : {
      open: this.handleHotkeyOpen,
      openProfile: this.handleHotkeyOpenProfile,
      moveUp: this.handleHotkeyMoveUp,
      moveDown: this.handleHotkeyMoveDown,
      toggleHidden: this.handleHotkeyToggleHidden,
      toggleSensitive: this.handleHotkeyToggleSensitive,
      openMedia: this.handleHotkeyOpenMedia,
    };

    let media, isCardMediaWithSensitive, prepend, rebloggedByText;

    if (hidden) {
      return (
        <HotKeys handlers={handlers}>
          <div ref={this.handleRef} className={classNames('status__wrapper', { focusable: !this.props.muted })} tabIndex={0}>
            <span>{status.getIn(['account', 'display_name']) || status.getIn(['account', 'username'])}</span>
            <span>{status.get('content')}</span>
          </div>
        </HotKeys>
      );
    }

    const connectUp = previousId && previousId === status.get('in_reply_to_id');
    const connectToRoot = rootId && rootId === status.get('in_reply_to_id');
    const connectReply = nextInReplyToId && nextInReplyToId === status.get('id');

    if (showThread && status.get('in_reply_to_id') && status.get('in_reply_to_account_id') === status.getIn(['account', 'id'])) {
      const display_name_html = { __html: status.getIn(['account', 'display_name_html']) };

      prepend = (
        <div className='status__prepend'>
          <div className='status__prepend-icon-wrapper'><Icon id='reply' className='status__prepend-icon' fixedWidth /></div>
          <FormattedMessage id='status.replied_to' defaultMessage='Replied to {name}' values={{ name: <a onClick={this.handlePrependAccountClick} data-id={status.getIn(['account', 'id'])} href={`/@${status.getIn(['account', 'acct'])}`} className='status__display-name muted'><bdi><strong dangerouslySetInnerHTML={display_name_html} /></bdi></a> }} />
        </div>
      );
    }

    isCardMediaWithSensitive = false;

    if (status.get('media_attachments').size > 0) {
      const language = status.getIn(['translation', 'language']) || status.get('language');

      if (this.props.muted) {
        media = (
          <AttachmentList
            compact
            media={status.get('media_attachments')}
          />
        );
      } else if (status.getIn(['media_attachments', 0, 'type']) === 'audio') {
        const attachment = status.getIn(['media_attachments', 0]);
        const description = attachment.getIn(['translation', 'description']) || attachment.get('description');

        media = (
          <Bundle fetchComponent={Audio} loading={this.renderLoadingAudioPlayer} >
            {Component => (
              <Component
                src={attachment.get('url')}
                alt={description}
                lang={language}
                poster={attachment.get('preview_url') || status.getIn(['account', 'avatar_static'])}
                backgroundColor={attachment.getIn(['meta', 'colors', 'background'])}
                foregroundColor={attachment.getIn(['meta', 'colors', 'foreground'])}
                accentColor={attachment.getIn(['meta', 'colors', 'accent'])}
                duration={attachment.getIn(['meta', 'original', 'duration'], 0)}
                width={this.props.cachedMediaWidth}
                height={110}
                cacheWidth={this.props.cacheMediaWidth}
                sensitive={status.get('sensitive')}
                blurhash={attachment.get('blurhash')}
                visible={this.state.showMedia}
                onToggleVisibility={this.handleToggleMediaVisibility}
              />
            )}
          </Bundle>
        );
      } else if (status.getIn(['media_attachments', 0, 'type']) === 'video') {
        const attachment = status.getIn(['media_attachments', 0]);
        const description = attachment.getIn(['translation', 'description']) || attachment.get('description');

        media = (
          <Bundle fetchComponent={Video} loading={this.renderLoadingVideoPlayer} >
            {Component => (
              <Component
                preview={attachment.get('preview_url')}
                frameRate={attachment.getIn(['meta', 'original', 'frame_rate'])}
                aspectRatio={`${attachment.getIn(['meta', 'original', 'width'])} / ${attachment.getIn(['meta', 'original', 'height'])}`}
                blurhash={attachment.get('blurhash')}
                src={attachment.get('url')}
                alt={description}
                lang={language}
                sensitive={status.get('sensitive')}
                onOpenVideo={this.handleOpenVideo}
                visible={this.state.showMedia}
                onToggleVisibility={this.handleToggleMediaVisibility}
              />
            )}
          </Bundle>
        );
      } else {
        media = (
          <Bundle fetchComponent={MediaGallery} loading={this.renderLoadingMediaGallery}>
            {Component => (
              <Component
                media={status.get('media_attachments')}
                lang={language}
                sensitive={status.get('sensitive')}
                height={110}
                onOpenMedia={this.handleOpenMedia}
                cacheWidth={this.props.cacheMediaWidth}
                defaultWidth={this.props.cachedMediaWidth}
                visible={this.state.showMedia}
                onToggleVisibility={this.handleToggleMediaVisibility}
              />
            )}
          </Bundle>
        );
      }
    } else if (status.get('card') && !this.props.muted) {
      media = (
        <Card
          onOpenMedia={this.handleOpenMedia}
          card={status.get('card')}
          compact
          sensitive={status.get('sensitive') && !status.get('spoiler_text')}
        />
      );
      isCardMediaWithSensitive = status.get('spoiler_text').length > 0;
    }

    const {statusContentProps, hashtagBar} = getHashtagBarForStatus(status);
    const expanded = !status.get('hidden') || status.get('spoiler_text').length === 0;

    return (
      <HotKeys handlers={handlers}>
        <div className={classNames('status__wrapper', 'status__wrapper__compact', `status__wrapper-${status.get('visibility_ex')}`, { 'status__wrapper-reply': !!status.get('in_reply_to_id'), unread, focusable: !this.props.muted })} tabIndex={this.props.muted ? null : 0} data-featured={featured ? 'true' : null} aria-label={textForScreenReader(intl, status, rebloggedByText)} ref={this.handleRef} data-nosnippet={status.getIn(['account', 'noindex'], true) || undefined}>
          {prepend}

          <div className={classNames('status', `status-${status.get('visibility_ex')}`, { 'status-reply': !!status.get('in_reply_to_id'), 'status--in-thread': !!rootId, 'status--first-in-thread': previousId && (!connectUp || connectToRoot), muted: this.props.muted })} data-id={status.get('id')}>
            {(connectReply || connectUp || connectToRoot) && <div className={classNames('status__line', { 'status__line--full': connectReply, 'status__line--first': !status.get('in_reply_to_id') && !connectToRoot })} />}

            {/* eslint-disable-next-line jsx-a11y/no-static-element-interactions */}
            <div onClick={this.handleClick} className='status__info'>
              <a href={`/@${status.getIn(['account', 'acct'])}/${status.get('id')}`} className='status__relative-time' target='_blank' rel='noopener noreferrer'>
                <RelativeTimestamp timestamp={status.get('created_at')} />{status.get('edited_at') && <abbr title={intl.formatMessage(messages.edited, { date: intl.formatDate(status.get('edited_at'), { hour12: false, year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }) })}> *</abbr>}
              </a>

              <a onClick={this.handleAccountClick} href={`/@${status.getIn(['account', 'acct'])}`} title={status.getIn(['account', 'acct'])} className='status__display-name' target='_blank' rel='noopener noreferrer'>
                <div className='status__avatar status__avatar__compact'>
                  <Avatar account={status.get('account')} size={24} inline />
                </div>

                <DisplayName account={status.get('account')} />
              </a>
            </div>

            <StatusContent
              status={status}
              onClick={this.handleClick}
              expanded={expanded}
              onExpandedToggle={this.handleExpandedToggle}
              onTranslate={this.handleTranslate}
              collapsible
              onCollapsedToggle={this.handleCollapsedToggle}
              {...statusContentProps}
            />

            {(!isCardMediaWithSensitive || !status.get('hidden')) && media}

            {(!status.get('spoiler_text') || expanded) && hashtagBar}
          </div>
        </div>
      </HotKeys>
    );
  }

}

export default injectIntl(CompactedStatus);
