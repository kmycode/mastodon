import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';


import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';

import AddIcon from 'mastodon/../material-icons/400-24px/add.svg?react';
import BookmarkIcon from 'mastodon/../material-icons/400-24px/bookmark-fill.svg?react';
import CloseIcon from 'mastodon/../material-icons/400-24px/close.svg?react';
import { Icon }  from 'mastodon/components/icon';

import { removeFromBookmarkCategoryAdder, addToBookmarkCategoryAdder } from '../../../actions/bookmark_categories';
import { IconButton }  from '../../../components/icon_button';

const messages = defineMessages({
  remove: { id: 'bookmark_categories.status.remove', defaultMessage: 'Remove from bookmark category' },
  add: { id: 'bookmark_categories.status.add', defaultMessage: 'Add to bookmark category' },
});

const MapStateToProps = (state, { bookmarkCategoryId, added }) => ({
  bookmarkCategory: state.get('bookmark_categories').get(bookmarkCategoryId),
  added: typeof added === 'undefined' ? state.getIn(['bookmarkCategoryAdder', 'bookmarkCategories', 'items']).includes(bookmarkCategoryId) : added,
});

const mapDispatchToProps = (dispatch, { bookmarkCategoryId }) => ({
  onRemove: () => dispatch(removeFromBookmarkCategoryAdder(bookmarkCategoryId)),
  onAdd: () => dispatch(addToBookmarkCategoryAdder(bookmarkCategoryId)),
});

class BookmarkCategory extends ImmutablePureComponent {

  static propTypes = {
    bookmarkCategory: ImmutablePropTypes.map.isRequired,
    intl: PropTypes.object.isRequired,
    onRemove: PropTypes.func.isRequired,
    onAdd: PropTypes.func.isRequired,
    added: PropTypes.bool,
  };

  static defaultProps = {
    added: false,
  };

  render () {
    const { bookmarkCategory, intl, onRemove, onAdd, added } = this.props;

    let button;

    if (added) {
      button = <IconButton icon='times' iconComponent={CloseIcon} title={intl.formatMessage(messages.remove)} onClick={onRemove} />;
    } else {
      button = <IconButton icon='plus' iconComponent={AddIcon} title={intl.formatMessage(messages.add)} onClick={onAdd} />;
    }

    return (
      <div className='list'>
        <div className='list__wrapper'>
          <div className='list__display-name'>
            <Icon id='bookmark' icon={BookmarkIcon} className='column-link__icon' fixedWidth />
            {bookmarkCategory.get('title')}
          </div>

          <div className='account__relationship'>
            {button}
          </div>
        </div>
      </div>
    );
  }

}

export default connect(MapStateToProps, mapDispatchToProps)(injectIntl(BookmarkCategory));
