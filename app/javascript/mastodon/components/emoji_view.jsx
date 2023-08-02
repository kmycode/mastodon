import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import emojify from '../features/emoji/emoji';

export default class EmojiView extends PureComponent {

  static propTypes = {
    name: PropTypes.string,
    url: PropTypes.string,
    staticUrl: PropTypes.string,
  };

  render () {
    const { name, url, staticUrl } = this.props;

    let emojiHtml = null;
    if (url) {
      let customEmojis = {};
      customEmojis[`:${name}:`] = { url, static_url: staticUrl };
      emojiHtml = emojify(`:${name}:`, customEmojis);
    } else {
      emojiHtml = emojify(name);
    }

    return (
      <span className='emoji' dangerouslySetInnerHTML={{ __html: emojiHtml }} />
    );
  }

}
