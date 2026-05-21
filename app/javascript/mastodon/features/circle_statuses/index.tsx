import { useEffect, useRef, useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { useParams } from 'react-router';

import { Helmet } from '@unhead/react/helmet';

import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import {
  expandCircleStatuses,
  fetchCircle,
  fetchCircleStatuses,
} from 'mastodon/actions/circles';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import { Column } from 'mastodon/components/column';
import type { ColumnRef } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import StatusList from 'mastodon/components/status_list';
import { getSubStatusList } from 'mastodon/selectors';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const CircleStatuses: React.FC<{
  columnId: string;
  multiColumn: boolean;
}> = ({ columnId, multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id: string }>();
  const columnRef = useRef<ColumnRef>(null);
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

  const handleHeaderClick = useCallback(() => {
    columnRef.current?.scrollTop();
  }, []);

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
    <Column
      bindToDocument={!multiColumn}
      ref={columnRef}
      label={circle?.get('title')}
    >
      <ColumnHeader
        icon='bookmark'
        iconComponent={CircleIcon}
        title={circle?.get('title')}
        onPin={handlePin}
        onMove={handleMove}
        onClick={handleHeaderClick}
        pinned={pinned}
        multiColumn={multiColumn}
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
