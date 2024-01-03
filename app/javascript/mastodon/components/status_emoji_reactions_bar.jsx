import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl } from 'react-intl';

import classNames from 'classnames';

import ImmutablePropTypes from 'react-immutable-proptypes';

import { isHideItem } from 'mastodon/initial_state';

import EmojiView from './emoji_view';

class EmojiReactionButton extends PureComponent {

  static propTypes = {
    name: PropTypes.string,
    domain: PropTypes.string,
    url: PropTypes.string,
    staticUrl: PropTypes.string,
    count: PropTypes.number.isRequired,
    me: PropTypes.bool,
    onEmojiReact: PropTypes.func,
    onUnEmojiReact: PropTypes.func,
  };

  onClick = () => {
    const { name, domain, me } = this.props;

    const nameParameter = domain ? `${name}@${domain}` : name;
    if (me) {
      if (this.props.onUnEmojiReact) this.props.onUnEmojiReact(nameParameter);
    } else {
      if (this.props.onEmojiReact) this.props.onEmojiReact(nameParameter);
    }
  };

  render () {
    const { name, url, staticUrl, count, me } = this.props;

    const classList = {
      'emoji-reactions-bar__button': true,
      'toggled': me,
    };

    const countView = count !== undefined && <span className='count'>{count}</span>;

    return (
      <button className={classNames(classList)} type='button' onClick={this.onClick}>
        <span className='emoji'>
          <EmojiView name={name} url={url} staticUrl={staticUrl} />
        </span>
        {countView}
      </button>
    );
  }

}

class StatusEmojiReactionsBar extends PureComponent {

  static propTypes = {
    emojiReactions: ImmutablePropTypes.list.isRequired,
    status: ImmutablePropTypes.map,
    onEmojiReact: PropTypes.func,
    onUnEmojiReact: PropTypes.func,
    myReactionOnly: PropTypes.bool,
  };

  onEmojiReact = (name) => {
    if (!this.props.onEmojiReact) return;
    this.props.onEmojiReact(this.props.status, name);
  };

  onUnEmojiReact = (name) => {
    if (!this.props.onUnEmojiReact) return;
    this.props.onUnEmojiReact(this.props.status, name);
  };

  render () {
    const { emojiReactions, myReactionOnly } = this.props;

    const isShowCount = !isHideItem('emoji_reaction_count');

    const emojiButtons = Array.from(emojiReactions)
      .filter(emoji => emoji.get('count') !== 0)
      .filter(emoji => !myReactionOnly || emoji.get('me'))
      .map((emoji, index) => (
        <EmojiReactionButton
          key={index}
          name={emoji.get('name')}
          count={isShowCount ? (myReactionOnly ? 1 : emoji.get('count')) : undefined}
          me={emoji.get('me')}
          url={emoji.get('url')}
          staticUrl={emoji.get('static_url')}
          domain={emoji.get('domain')}
          onEmojiReact={this.onEmojiReact}
          onUnEmojiReact={this.onUnEmojiReact}
        />));

    return (
      <div className='status__emoji-reactions-bar'>
        {emojiButtons}
      </div>
    );
  }

}

export default injectIntl(StatusEmojiReactionsBar);
