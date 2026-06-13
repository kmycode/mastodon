import { useEffect, useMemo, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { Helmet } from '@unhead/react/helmet';

import { NotSignedInIndicator } from '@/mastodon/components/not_signed_in_indicator';
import { useIdentity } from '@/mastodon/identity_context';
import AddIcon from '@/material-icons/400-24px/add.svg?react';
import BookmarkIcon from '@/material-icons/400-24px/bookmark-fill.svg?react';
import BookmarksIcon from '@/material-icons/400-24px/bookmarks.svg?react';
import MoreHorizIcon from '@/material-icons/400-24px/more_horiz.svg?react';
import SquigglyArrow from '@/svg-icons/squiggly_arrow.svg?react';
import { fetchBookmarkCategories } from 'mastodon/actions/bookmark_categories';
import { openModal } from 'mastodon/actions/modal';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { Dropdown } from 'mastodon/components/dropdown_menu';
import { Icon } from 'mastodon/components/icon';
import ScrollableList from 'mastodon/components/scrollable_list';
import { getOrderedBookmarkCategories } from 'mastodon/selectors/bookmark_categories';
import { useAppSelector, useAppDispatch } from 'mastodon/store';

const messages = defineMessages({
  heading: {
    id: 'column.bookmark_categories',
    defaultMessage: 'BookmarkCategories',
  },
  create: {
    id: 'bookmark_categories.create_bookmark_category',
    defaultMessage: 'Create category',
  },
  edit: {
    id: 'bookmark_categories.edit',
    defaultMessage: 'Edit category',
  },
  delete: {
    id: 'bookmark_categories.delete',
    defaultMessage: 'Delete category',
  },
  more: { id: 'status.more', defaultMessage: 'More' },
});

const BookmarkCategoryItem: React.FC<{
  id: string;
  title: string;
}> = ({ id, title }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();

  const handleDeleteClick = useCallback(() => {
    dispatch(
      openModal({
        modalType: 'CONFIRM_DELETE_BOOKMARK_CATEGORY',
        modalProps: {
          bookmark_categoryId: id,
        },
      }),
    );
  }, [dispatch, id]);

  const menu = useMemo(
    () => [
      {
        text: intl.formatMessage(messages.edit),
        to: `/bookmark_categories/${id}/edit`,
      },
      { text: intl.formatMessage(messages.delete), action: handleDeleteClick },
    ],
    [intl, id, handleDeleteClick],
  );

  return (
    <div className='lists__item'>
      <Link to={`/bookmark_categories/${id}`} className='lists__item__title'>
        <Icon id='bookmark_category-ul' icon={BookmarkIcon} />
        <span>{title}</span>
      </Link>

      <Dropdown
        scrollKey='bookmark_categories'
        items={menu}
        icon='ellipsis-h'
        iconComponent={MoreHorizIcon}
        title={intl.formatMessage(messages.more)}
      />
    </div>
  );
};

const BookmarkCategories: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const bookmark_categories = useAppSelector((state) =>
    getOrderedBookmarkCategories(state),
  );
  const { signedIn } = useIdentity();

  useEffect(() => {
    if (signedIn) {
      void dispatch(fetchBookmarkCategories());
    }
  }, [signedIn, dispatch]);

  const emptyMessage = (
    <>
      <span>
        <FormattedMessage
          id='bookmark_categories.no_bookmark_categories_yet'
          defaultMessage='No bookmark_categories yet.'
        />
        <br />
        <FormattedMessage
          id='bookmark_categories.create_a_bookmark_category_to_organize'
          defaultMessage='Create a new bookmark_category to organize your Home feed'
        />
      </span>

      <SquigglyArrow className='empty-column-indicator__arrow' />
    </>
  );

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.heading)}
    >
      <ColumnHeader
        title={intl.formatMessage(messages.heading)}
        icon='bookmark_category-ul'
        iconComponent={BookmarkIcon}
        multiColumn={multiColumn}
        extraButton={
          signedIn && (
            <Link
              to='/bookmark_categories/new'
              className='column-header__button'
              title={intl.formatMessage(messages.create)}
              aria-label={intl.formatMessage(messages.create)}
            >
              <Icon id='plus' icon={AddIcon} />
            </Link>
          )
        }
      />

      <ScrollableList
        scrollKey='bookmark_categories'
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
        alwaysPrepend
        prepend={
          <div className='lists__item'>
            <Link to={'/bookmarks'} className='lists__item__title'>
              <Icon id='bookmarks' icon={BookmarksIcon} />
              <span>
                <FormattedMessage
                  id='bookmark_categories.all_bookmarks'
                  defaultMessage='All bookmarks'
                />
              </span>
            </Link>
          </div>
        }
      >
        {signedIn ? (
          bookmark_categories.map((bookmark_category) => (
            <BookmarkCategoryItem
              key={bookmark_category.id}
              id={bookmark_category.id}
              title={bookmark_category.title}
            />
          ))
        ) : (
          <NotSignedInIndicator />
        )}
      </ScrollableList>

      <Helmet>
        <title>{intl.formatMessage(messages.heading)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default BookmarkCategories;
