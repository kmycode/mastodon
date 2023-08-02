import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { injectIntl } from 'react-intl';

import classNames from 'classnames';

import ImmutablePropTypes from 'react-immutable-proptypes';

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

    return (
      <button className={classNames(classList)} type='button' onClick={this.onClick}>
        <span className='emoji'>
          <EmojiView name={name} url={url} staticUrl={staticUrl} />
        </span>
        <span className='count'>{count}</span>
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
    const { emojiReactions } = this.props;

    const emojiButtons = Array.from(emojiReactions).filter(emoji => emoji.get('count') !== 0).map((emoji, index) => (
      <EmojiReactionButton
        key={index}
        name={emoji.get('name')}
        count={emoji.get('count')}
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
