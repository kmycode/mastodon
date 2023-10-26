import PropTypes from 'prop-types';

import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';

import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import { createSelector } from 'reselect';

import { ReactComponent as BookmarksIcon } from '@material-symbols/svg-600/outlined/bookmark-fill.svg';
import { ReactComponent as BookmarkIcon } from '@material-symbols/svg-600/outlined/bookmark.svg';

import { fetchBookmarkCategories } from 'mastodon/actions/bookmark_categories';
import Column from 'mastodon/components/column';
import ColumnHeader from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import ScrollableList from 'mastodon/components/scrollable_list';
import ColumnLink from 'mastodon/features/ui/components/column_link';
import ColumnSubheading from 'mastodon/features/ui/components/column_subheading';

import NewListForm from './components/new_bookmark_category_form';

const messages = defineMessages({
  heading: { id: 'column.bookmark_categories', defaultMessage: 'Bookmark categories' },
  subheading: { id: 'bookmark_categories.subheading', defaultMessage: 'Your categories' },
  allBookmarks: { id: 'bookmark_categories.all_bookmarks', defaultMessage: 'All bookmarks' },
});

const getOrderedCategories = createSelector([state => state.get('bookmark_categories')], categories => {
  if (!categories) {
    return categories;
  }

  return categories.toList().filter(item => !!item && typeof item.get('title') !== 'undefined' && item.get('title') !== null).sort((a, b) => a.get('title').localeCompare(b.get('title')));
});

const mapStateToProps = state => ({
  categories: getOrderedCategories(state),
});

class BookmarkCategories extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    categories: ImmutablePropTypes.list,
    intl: PropTypes.object.isRequired,
    multiColumn: PropTypes.bool,
  };

  UNSAFE_componentWillMount () {
    this.props.dispatch(fetchBookmarkCategories());
  }

  render () {
    const { intl, categories, multiColumn } = this.props;

    if (!categories) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.bookmark_categories' defaultMessage="You don't have any categories yet. When you create one, it will show up here." />;

    return (
      <Column bindToDocument={!multiColumn} label={intl.formatMessage(messages.heading)}>
        <ColumnHeader title={intl.formatMessage(messages.heading)} icon='bookmark' iconComponent={BookmarksIcon} multiColumn={multiColumn} />

        <NewListForm />

        <ColumnLink to='/bookmarks' icon='bookmark' iconComponent={BookmarkIcon} text={intl.formatMessage(messages.allBookmarks)} />
        <ScrollableList
          scrollKey='bookmark_categories'
          emptyMessage={emptyMessage}
          prepend={<ColumnSubheading text={intl.formatMessage(messages.subheading)} />}
          bindToDocument={!multiColumn}
        >
          {categories.map(category =>
            <ColumnLink key={category.get('id')} to={`/boozkmark_categories/${category.get('id')}`} icon='bookmark' iconComponent={BookmarkIcon} text={category.get('title')} />,
          )}
        </ScrollableList>

        <Helmet>
          <title>{intl.formatMessage(messages.heading)}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(injectIntl(BookmarkCategories));
