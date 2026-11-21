import { useEffect, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { useParams } from 'react-router';

import { Helmet } from '@unhead/react/helmet';

import { openModal } from '@/mastodon/actions/modal';
import { MultiColumnMenuItems } from '@/mastodon/components/column_header/multicolumn_settings';
import { MenuItem, MenuItemLink } from '@/mastodon/components/menu';
import {
  expandCircleStatuses,
  fetchCircle,
  fetchCircleStatuses,
} from 'mastodon/actions/circles';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { Column } from 'mastodon/components/column';
import {
  ColumnHeader,
  ColumnSettingsMenu,
} from 'mastodon/components/column_header';
import StatusList from 'mastodon/components/status_list';
import { getSubStatusList } from 'mastodon/selectors';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const CircleStatuses: React.FC<{
  columnId: string;
  multiColumn: boolean;
}> = ({ columnId, multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id: string }>();
  const statusIds = useAppSelector((state) =>
    getSubStatusList(state, 'circle', id),
  );
  const isLoading = useAppSelector(
    (state) =>
      state.status_lists.getIn(
        ['circle_statuses', id, 'isLoading'],
        true,
      ) as boolean,
  );
  const hasMore = useAppSelector(
    (state) => !!state.status_lists.getIn(['circle_statuses', id, 'next']),
  );
  const circle = useAppSelector((state) => state.circles.get(id));

  useEffect(() => {
    dispatch(fetchCircle(id));
    dispatch(fetchCircleStatuses(id));
  }, [dispatch, id]);

  const handlePin = useCallback(() => {
    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('CIRCLE_STATUSES', { id }));
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
        modalType: 'CONFIRM_DELETE_CIRCLE',
        modalProps: { circleId: id, columnId },
      }),
    );
  }, [dispatch, columnId, id]);

  const handleLoadMore = useCallback(() => {
    dispatch(expandCircleStatuses(id));
  }, [dispatch, id]);

  const pinned = !!columnId;

  const emptyMessage = (
    <FormattedMessage
      id='empty_column.circle_statuses'
      defaultMessage="You don't have any circle posts yet. When you post one as circle, it will show up here."
    />
  );

  return (
    <Column bindToDocument={!multiColumn} label={circle?.get('title')}>
      <ColumnHeader
        title={circle?.get('title')}
        withBackButton={multiColumn && !pinned && 'auto'}
        extraButtons={
          <ColumnSettingsMenu
            label={
              <FormattedMessage
                id='circles.options'
                defaultMessage='Circle Options'
              />
            }
          >
            <MenuItemLink as='link' to={`/circles/${id}/edit`}>
              <FormattedMessage
                id='circles.edit'
                defaultMessage='Edit circle'
              />
            </MenuItemLink>
            <MenuItem onClick={handleDelete}>
              <FormattedMessage
                id='circles.delete'
                defaultMessage='Delete circle'
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
        <title>{circle?.get('title')}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default CircleStatuses;
