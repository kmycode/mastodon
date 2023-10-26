import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import { Button } from 'mastodon/components/button';
import EmojiPickerDropdownContainer from 'mastodon/features/compose/containers/emoji_picker_dropdown_container';
import emojify from 'mastodon/features/emoji/emoji';
import { autoPlayGif } from 'mastodon/initial_state';

const messages = defineMessages({
  remove: { id: 'reaction_deck.remove', defaultMessage: 'Remove' },
});

class ReactionEmoji extends ImmutablePureComponent {

  static propTypes = {
    index: PropTypes.number,
    emoji: PropTypes.string,
    emojiMap: ImmutablePropTypes.map.isRequired,
    onChange: PropTypes.func.isRequired,
    onRemove: PropTypes.func.isRequired,
  };

  static defaultProps = {
    emoji: '',
  };

  handleChange = (emoji) => {
    this.props.onChange(this.props.index, emoji);
  };

  handleRemove = () => {
    this.props.onRemove(this.props.index);
  };

  render () {
    const { intl, emojiMap, emoji } = this.props;

    let content = null;

    if (emojiMap.get(emoji)) {
      const filename  = autoPlayGif ? emojiMap.getIn([emoji, 'url']) : emojiMap.getIn([emoji, 'static_url']);
      const shortCode = `:${emoji}:`;

      content = (
        <img
          draggable='false'
          className='emojione custom-emoji'
          alt={shortCode}
          title={shortCode}
          src={filename}
        />
      );
    } else {
      const html = { __html: emojify(emoji) };
      content = (
        <span dangerouslySetInnerHTML={html} />
      );
    }

    return (
      <div className='reaction_deck__emoji'>
        <div className='reaction_deck__emoji__wrapper'>
          <div className='reaction_deck__emoji__wrapper__content'>
            <EmojiPickerDropdownContainer onPickEmoji={this.handleChange} />
            <div>
              {content}
            </div>
          </div>
          <div className='reaction_deck__emoji__wrapper__options'>
            <Button secondary text={intl.formatMessage(messages.remove)} onClick={this.handleRemove} />
          </div>
        </div>
      </div>
    );
  }

}

export default connect()(injectIntl(ReactionEmoji));
