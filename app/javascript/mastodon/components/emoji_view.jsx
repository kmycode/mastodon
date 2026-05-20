import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { Emoji } from './emoji';

export default class EmojiView extends PureComponent {

  static propTypes = {
    name: PropTypes.string,
    url: PropTypes.string,
    staticUrl: PropTypes.string,
  };

  render () {
    const { name, url, staticUrl } = this.props;

    if (url) {
      return <Emoji code={`:${name}:`} />
    } else {
      return <Emoji code={name} />
    }
  }

}
