import { useEffect, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { useParams } from 'react-router';

import { Helmet } from '@unhead/react/helmet';

import { openModal } from '@/mastodon/actions/modal';
import { MultiColumnMenuItems } from '@/mastodon/components/column_header/multicolumn_settings';
import { MenuItem, MenuItemLink } from '@/mastodon/components/menu';
import {
  expandBookmarkCategoryStatuses,
  fetchBookmarkCategory,
  fetchBookmarkCategoryStatuses,
} from 'mastodon/actions/bookmark_categories';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { Column } from 'mastodon/components/column';
import {
  ColumnHeader,
  ColumnSettingsMenu,
} from 'mastodon/components/column_header';
import StatusList from 'mastodon/components/status_list';
import { getSubStatusList } from 'mastodon/selectors';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const BookmarkCategoryStatuses: React.FC<{
  columnId: string;
  multiColumn: boolean;
}> = ({ columnId, multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id: string }>();
  const statusIds = useAppSelector((state) =>
    getSubStatusList(state, 'bookmark_category', id),
  );
  const isLoading = useAppSelector(
    (state) =>
      state.status_lists.getIn(
        ['bookmark_category_statuses', id, 'isLoading'],
        true,
      ) as boolean,
  );
  const hasMore = useAppSelector(
    (state) =>
      !!state.status_lists.getIn(['bookmark_category_statuses', id, 'next']),
  );
  const bookmarkCategory = useAppSelector((state) =>
    state.bookmark_categories.get(id),
  );

  useEffect(() => {
    dispatch(fetchBookmarkCategory(id));
    dispatch(fetchBookmarkCategoryStatuses(id));
  }, [dispatch, id]);

  const handlePin = useCallback(() => {
    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('BOOKMARKS_EX', { id }));
    }
  }, [dispatch, columnId, id]);

  const handleMove = useCallback(
    (dir: number) => {
      dispatch(moveColumn(columnId, dir));
    },
    [dispatch, columnId],
  );

  const handleDelete = useCallback(() => {
    dispatch(
      openModal({
        modalType: 'CONFIRM_DELETE_BOOKMARK_CATEGORY',
        modalProps: { bookmark_categoryId: id, columnId },
      }),
    );
  }, [dispatch, columnId, id]);

  const handleLoadMore = useCallback(() => {
    dispatch(expandBookmarkCategoryStatuses(id));
  }, [dispatch, id]);

  const pinned = !!columnId;

  const emptyMessage = (
    <FormattedMessage
      id='empty_column.bookmarked_statuses'
      defaultMessage="You don't have any bookmarked posts yet. When you bookmark one, it will show up here."
    />
  );

  return (
    <Column
      bindToDocument={!multiColumn}
      label={bookmarkCategory?.get('title')}
    >
      <ColumnHeader
        title={bookmarkCategory?.get('title')}
        extraButtons={
          <ColumnSettingsMenu
            label={
              <FormattedMessage
                id='bookmark_categories.options'
                defaultMessage='Category Options'
              />
            }
          >
            <MenuItemLink as='link' to={`/bookmark_categories/${id}/edit`}>
              <FormattedMessage
                id='bookmark_categories.edit'
                defaultMessage='Edit category'
              />
            </MenuItemLink>
            <MenuItem onClick={handleDelete}>
              <FormattedMessage
                id='bookmark_categories.delete'
                defaultMessage='Delete category'
              />
            </MenuItem>

            {multiColumn && (
              <MultiColumnMenuItems
                withDivider
                pinned={pinned}
                onPin={handlePin}
                onMove={handleMove}
              />
            )}
          </ColumnSettingsMenu>
        }
      />

      <StatusList
        trackScroll={!pinned}
        statusIds={statusIds}
        scrollKey={`bookmark_ex_statuses-${columnId}`}
        hasMore={hasMore}
        isLoading={isLoading}
        onLoadMore={handleLoadMore}
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
      />

      <Helmet>
        <title>{bookmarkCategory?.get('title')}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default BookmarkCategoryStatuses;
