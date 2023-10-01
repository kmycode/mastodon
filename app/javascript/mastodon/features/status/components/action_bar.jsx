import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import classNames from 'classnames';

import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';

import { PERMISSION_MANAGE_USERS, PERMISSION_MANAGE_FEDERATION } from 'mastodon/permissions';


import { IconButton } from '../../../components/icon_button';
import DropdownMenuContainer from '../../../containers/dropdown_menu_container';
import { enableEmojiReaction , bookmarkCategoryNeeded, me } from '../../../initial_state';
import EmojiPickerDropdown from '../../compose/containers/emoji_picker_dropdown_container';

const messages = defineMessages({
  delete: { id: 'status.delete', defaultMessage: 'Delete' },
  redraft: { id: 'status.redraft', defaultMessage: 'Delete & re-draft' },
  edit: { id: 'status.edit', defaultMessage: 'Edit' },
  direct: { id: 'status.direct', defaultMessage: 'Privately mention @{name}' },
  mention: { id: 'status.mention', defaultMessage: 'Mention @{name}' },
  mentions: { id: 'status.mentions', defaultMessage: 'Mentioned users' },
  reply: { id: 'status.reply', defaultMessage: 'Reply' },
  reblog: { id: 'status.reblog', defaultMessage: 'Boost' },
  cancel_reblog: { id: 'status.cancel_reblog_private', defaultMessage: 'Unboost' },
  reblog_private: { id: 'status.reblog_private', defaultMessage: 'Boost with original visibility' },
  cancel_reblog_private: { id: 'status.cancel_reblog_private', defaultMessage: 'Unboost' },
  cannot_reblog: { id: 'status.cannot_reblog', defaultMessage: 'This post cannot be boosted' },
  favourite: { id: 'status.favourite', defaultMessage: 'Favorite' },
  bookmark: { id: 'status.bookmark', defaultMessage: 'Bookmark' },
  bookmark_category: { id: 'status.bookmark_category', defaultMessage: 'Bookmark category' },
  more: { id: 'status.more', defaultMessage: 'More' },
  mute: { id: 'status.mute', defaultMessage: 'Mute @{name}' },
  muteConversation: { id: 'status.mute_conversation', defaultMessage: 'Mute conversation' },
  unmuteConversation: { id: 'status.unmute_conversation', defaultMessage: 'Unmute conversation' },
  block: { id: 'status.block', defaultMessage: 'Block @{name}' },
  report: { id: 'status.report', defaultMessage: 'Report @{name}' },
  share: { id: 'status.share', defaultMessage: 'Share' },
  pin: { id: 'status.pin', defaultMessage: 'Pin on profile' },
  unpin: { id: 'status.unpin', defaultMessage: 'Unpin from profile' },
  embed: { id: 'status.embed', defaultMessage: 'Embed' },
  admin_account: { id: 'status.admin_account', defaultMessage: 'Open moderation interface for @{name}' },
  admin_status: { id: 'status.admin_status', defaultMessage: 'Open this post in the moderation interface' },
  admin_domain: { id: 'status.admin_domain', defaultMessage: 'Open moderation interface for {domain}' },
  copy: { id: 'status.copy', defaultMessage: 'Copy link to post' },
  reference: { id: 'status.reference', defaultMessage: 'Add reference' },
  quote: { id: 'status.quote', defaultMessage: 'Add ref (quote in other servers)' },
  blockDomain: { id: 'account.block_domain', defaultMessage: 'Block domain {domain}' },
  unblockDomain: { id: 'account.unblock_domain', defaultMessage: 'Unblock domain {domain}' },
  unmute: { id: 'account.unmute', defaultMessage: 'Unmute @{name}' },
  unblock: { id: 'account.unblock', defaultMessage: 'Unblock @{name}' },
  openOriginalPage: { id: 'account.open_original_page', defaultMessage: 'Open original page' },
  pickEmoji: { id: 'status.emoji_reaction.pick', defaultMessage: 'Pick emoji' },
});

const mapStateToProps = (state, { status }) => ({
  relationship: state.getIn(['relationships', status.getIn(['account', 'id'])]),
});

class ActionBar extends PureComponent {

  static contextTypes = {
    router: PropTypes.object,
    identity: PropTypes.object,
  };

  static propTypes = {
    status: ImmutablePropTypes.map.isRequired,
    relationship: ImmutablePropTypes.map,
    onReply: PropTypes.func.isRequired,
    onReblog: PropTypes.func.isRequired,
    onReblogForceModal: PropTypes.func.isRequired,
    onFavourite: PropTypes.func.isRequired,
    onEmojiReact: PropTypes.func.isRequired,
    onReference: PropTypes.func.isRequired,
    onQuote: PropTypes.func.isRequired,
    onBookmark: PropTypes.func.isRequired,
    onBookmarkCategoryAdder: PropTypes.func.isRequired,
    onDelete: PropTypes.func.isRequired,
    onEdit: PropTypes.func.isRequired,
    onDirect: PropTypes.func.isRequired,
    onMention: PropTypes.func.isRequired,
    onMute: PropTypes.func,
    onUnmute: PropTypes.func,
    onBlock: PropTypes.func,
    onUnblock: PropTypes.func,
    onBlockDomain: PropTypes.func,
    onUnblockDomain: PropTypes.func,
    onMuteConversation: PropTypes.func,
    onReport: PropTypes.func,
    onPin: PropTypes.func,
    onEmbed: PropTypes.func,
    intl: PropTypes.object.isRequired,
  };

  handleOpenMentions = () => {
    this.context.router.history.push(`/@${this.props.status.getIn(['account', 'acct'])}/${this.props.status.get('id')}/mentioned_users`);
  };

  handleReplyClick = () => {
    this.props.onReply(this.props.status);
  };

  handleReblogClick = (e) => {
    this.props.onReblog(this.props.status, e);
  };

  handleReblogForceModalClick = (e) => {
    this.props.onReblogForceModal(this.props.status, e);
  };

  handleFavouriteClick = () => {
    this.props.onFavourite(this.props.status);
  };

  handleBookmarkClick = (e) => {
    if (bookmarkCategoryNeeded) {
      this.props.onBookmarkCategoryAdder(this.props.status);
    } else {
      this.props.onBookmark(this.props.status, e);
    }
  };

  handleBookmarkCategoryAdderClick = () => {
    this.props.onBookmarkCategoryAdder(this.props.status);
  };

  handleDeleteClick = () => {
    this.props.onDelete(this.props.status, this.context.router.history);
  };

  handleRedraftClick = () => {
    this.props.onDelete(this.props.status, this.context.router.history, true);
  };

  handleEditClick = () => {
    this.props.onEdit(this.props.status, this.context.router.history);
  };

  handleDirectClick = () => {
    this.props.onDirect(this.props.status.get('account'), this.context.router.history);
  };

  handleMentionClick = () => {
    this.props.onMention(this.props.status.get('account'), this.context.router.history);
  };

  handleMuteClick = () => {
    const { status, relationship, onMute, onUnmute } = this.props;
    const account = status.get('account');

    if (relationship && relationship.get('muting')) {
      onUnmute(account);
    } else {
      onMute(account);
    }
  };

  handleBlockClick = () => {
    const { status, relationship, onBlock, onUnblock } = this.props;
    const account = status.get('account');

    if (relationship && relationship.get('blocking')) {
      onUnblock(account);
    } else {
      onBlock(status);
    }
  };

  handleBlockDomain = () => {
    const { status, onBlockDomain } = this.props;
    const account = status.get('account');

    onBlockDomain(account.get('acct').split('@')[1]);
  };

  handleUnblockDomain = () => {
    const { status, onUnblockDomain } = this.props;
    const account = status.get('account');

    onUnblockDomain(account.get('acct').split('@')[1]);
  };

  handleConversationMuteClick = () => {
    this.props.onMuteConversation(this.props.status);
  };

  handleReport = () => {
    this.props.onReport(this.props.status);
  };

  handlePinClick = () => {
    this.props.onPin(this.props.status);
  };

  handleShare = () => {
    navigator.share({
      url: this.props.status.get('url'),
    });
  };

  handleEmbed = () => {
    this.props.onEmbed(this.props.status);
  };

  handleCopy = () => {
    const url = this.props.status.get('url');
    navigator.clipboard.writeText(url);
  };

  handleReference = () => {
    this.props.onReference(this.props.status);
  };

  handleQuote = () => {
    this.props.onQuote(this.props.status);
  };

  handleEmojiPick = (data) => {
    this.props.onEmojiReact(this.props.status, data);
  };

  handleEmojiPickInnerButton = () => {};

  render () {
    const { status, relationship, intl } = this.props;
    const { signedIn, permissions } = this.context.identity;

    const publicStatus       = ['public', 'unlisted', 'public_unlisted', 'login'].includes(status.get('visibility_ex'));
    const anonymousStatus    = ['public', 'unlisted', 'public_unlisted'].includes(status.get('visibility_ex'));
    const pinnableStatus     = ['public', 'unlisted', 'public_unlisted', 'login', 'private'].includes(status.get('visibility_ex'));
    const mutingConversation = status.get('muted');
    const account            = status.get('account');
    const writtenByMe        = status.getIn(['account', 'id']) === me;
    const isRemote           = status.getIn(['account', 'username']) !== status.getIn(['account', 'acct']);
    const allowQuote         = status.getIn(['account', 'other_settings', 'allow_quote']);

    let menu = [];

    if (publicStatus && isRemote) {
      menu.push({ text: intl.formatMessage(messages.openOriginalPage), href: status.get('url') });
    }

    menu.push({ text: intl.formatMessage(messages.copy), action: this.handleCopy });

    if (publicStatus && 'share' in navigator) {
      menu.push({ text: intl.formatMessage(messages.share), action: this.handleShare });
    }

    if (anonymousStatus && (signedIn || !isRemote)) {
      menu.push({ text: intl.formatMessage(messages.embed), action: this.handleEmbed });
    }

    if (signedIn) {
      menu.push(null);
      menu.push({ text: intl.formatMessage(status.get('reblogged') ? messages.cancel_reblog : messages.reblog), action: this.handleReblogForceModalClick });

      if (publicStatus) {
        menu.push({ text: intl.formatMessage(messages.reference), action: this.handleReference });

        if (allowQuote) {
          menu.push({ text: intl.formatMessage(messages.quote), action: this.handleQuote });
        }
      }
      menu.push({ text: intl.formatMessage(messages.bookmark_category), action: this.handleBookmarkCategoryAdderClick });

      if (writtenByMe) {
        if (pinnableStatus) {
          menu.push({ text: intl.formatMessage(status.get('pinned') ? messages.unpin : messages.pin), action: this.handlePinClick });
          menu.push(null);
        }

        menu.push({ text: intl.formatMessage(messages.mentions), action: this.handleOpenMentions });
        menu.push({ text: intl.formatMessage(mutingConversation ? messages.unmuteConversation : messages.muteConversation), action: this.handleConversationMuteClick });
        menu.push(null);
        menu.push({ text: intl.formatMessage(messages.edit), action: this.handleEditClick });
        menu.push({ text: intl.formatMessage(messages.delete), action: this.handleDeleteClick, dangerous: true });
        menu.push({ text: intl.formatMessage(messages.redraft), action: this.handleRedraftClick, dangerous: true });
      } else {
        menu.push({ text: intl.formatMessage(messages.mention, { name: status.getIn(['account', 'username']) }), action: this.handleMentionClick });
        menu.push(null);

        if (relationship && relationship.get('muting')) {
          menu.push({ text: intl.formatMessage(messages.unmute, { name: account.get('username') }), action: this.handleMuteClick });
        } else {
          menu.push({ text: intl.formatMessage(messages.mute, { name: account.get('username') }), action: this.handleMuteClick, dangerous: true });
        }

        if (relationship && relationship.get('blocking')) {
          menu.push({ text: intl.formatMessage(messages.unblock, { name: account.get('username') }), action: this.handleBlockClick });
        } else {
          menu.push({ text: intl.formatMessage(messages.block, { name: account.get('username') }), action: this.handleBlockClick, dangerous: true });
        }

        menu.push({ text: intl.formatMessage(messages.report, { name: status.getIn(['account', 'username']) }), action: this.handleReport, dangerous: true });

        if (account.get('acct') !== account.get('username')) {
          const domain = account.get('acct').split('@')[1];

          menu.push(null);

          if (relationship && relationship.get('domain_blocking')) {
            menu.push({ text: intl.formatMessage(messages.unblockDomain, { domain }), action: this.handleUnblockDomain });
          } else {
            menu.push({ text: intl.formatMessage(messages.blockDomain, { domain }), action: this.handleBlockDomain, dangerous: true });
          }
        }

        if ((permissions & PERMISSION_MANAGE_USERS) === PERMISSION_MANAGE_USERS || (isRemote && (permissions & PERMISSION_MANAGE_FEDERATION) === PERMISSION_MANAGE_FEDERATION)) {
          menu.push(null);
          if ((permissions & PERMISSION_MANAGE_USERS) === PERMISSION_MANAGE_USERS) {
            menu.push({ text: intl.formatMessage(messages.admin_account, { name: status.getIn(['account', 'username']) }), href: `/admin/accounts/${status.getIn(['account', 'id'])}` });
            menu.push({ text: intl.formatMessage(messages.admin_status), href: `/admin/accounts/${status.getIn(['account', 'id'])}/statuses/${status.get('id')}` });
          }
          if (isRemote && (permissions & PERMISSION_MANAGE_FEDERATION) === PERMISSION_MANAGE_FEDERATION) {
            const domain = account.get('acct').split('@')[1];
            menu.push({ text: intl.formatMessage(messages.admin_domain, { domain: domain }), href: `/admin/instances/${domain}` });
          }
        }
      }
    }

    let replyIcon;
    if (status.get('in_reply_to_id', null) === null) {
      replyIcon = 'reply';
    } else {
      replyIcon = 'reply-all';
    }

    const reblogPrivate = status.getIn(['account', 'id']) === me && status.get('visibility_ex') === 'private';

    let reblogTitle;
    if (status.get('reblogged')) {
      reblogTitle = intl.formatMessage(messages.cancel_reblog_private);
    } else if (publicStatus) {
      reblogTitle = intl.formatMessage(messages.reblog);
    } else if (reblogPrivate) {
      reblogTitle = intl.formatMessage(messages.reblog_private);
    } else {
      reblogTitle = intl.formatMessage(messages.cannot_reblog);
    }

    const emojiReactionPolicy = account.getIn(['other_settings', 'emoji_reaction_policy']) || 'allow';
    const following = emojiReactionPolicy !== 'following_only' || (relationship && relationship.get('following'));
    const followed = emojiReactionPolicy !== 'followers_only' || (relationship && relationship.get('followed_by'));
    const mutual = emojiReactionPolicy !== 'mutuals_only' || (relationship && relationship.get('following') && relationship.get('followed_by'));
    const outside = emojiReactionPolicy !== 'outside_only' || (relationship && (relationship.get('following') || relationship.get('followed_by')));
    const denyFromAll = emojiReactionPolicy !== 'block' && emojiReactionPolicy !== 'block';
    const emojiPickerButton = (
      <IconButton icon='smile-o' onClick={this.handleEmojiPickInnerButton} title={intl.formatMessage(messages.pickEmoji)} />
    );
    const emojiPickerDropdown = enableEmojiReaction && denyFromAll && (writtenByMe || (following && followed && mutual && outside)) && (
      <div className='detailed-status__button'><EmojiPickerDropdown onPickEmoji={this.handleEmojiPick} button={emojiPickerButton} /></div>
    );

    return (
      <div className='detailed-status__action-bar'>
        <div className='detailed-status__button'><IconButton title={intl.formatMessage(messages.reply)} icon={status.get('in_reply_to_account_id') === status.getIn(['account', 'id']) ? 'reply' : replyIcon} onClick={this.handleReplyClick} /></div>
        <div className='detailed-status__button'><IconButton className={classNames({ reblogPrivate })} disabled={!publicStatus && !reblogPrivate} active={status.get('reblogged')} title={reblogTitle} icon='retweet' onClick={this.handleReblogClick} /></div>
        <div className='detailed-status__button'><IconButton className='star-icon' animate active={status.get('favourited')} title={intl.formatMessage(messages.favourite)} icon='star' onClick={this.handleFavouriteClick} /></div>
        <div className='detailed-status__button'><IconButton className='bookmark-icon' disabled={!signedIn} active={status.get('bookmarked')} title={intl.formatMessage(messages.bookmark)} icon='bookmark' onClick={this.handleBookmarkClick} /></div>
        {emojiPickerDropdown}

        <div className='detailed-status__action-bar-dropdown'>
          <DropdownMenuContainer size={18} icon='ellipsis-h' status={status} items={menu} direction='left' title={intl.formatMessage(messages.more)} />
        </div>
      </div>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(ActionBar));
