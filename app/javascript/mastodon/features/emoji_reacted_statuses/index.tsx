import { useEffect, useCallback } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from '@unhead/react/helmet';

import EmojiReactionIcon from '@/material-icons/400-24px/mood.svg?react';
import { addColumn, removeColumn, moveColumn } from 'mastodon/actions/columns';
import {
  fetchEmojiReactedStatuses,
  expandEmojiReactedStatuses,
} from 'mastodon/actions/emoji_reactions';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column/header';
import StatusList from 'mastodon/components/status_list';
import { getStatusList } from 'mastodon/selectors';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

const messages = defineMessages({
  heading: { id: 'column.emoji_reactions', defaultMessage: 'Stamps' },
});

const Favourites: React.FC<{ columnId: string; multiColumn: boolean }> = ({
  columnId,
  multiColumn,
}) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();
  const statusIds = useAppSelector((state) =>
    getStatusList(state, 'emoji_reactions'),
  );
  const isLoading = useAppSelector(
    (state) =>
      state.status_lists.getIn(
        ['emoji_reactions', 'isLoading'],
        true,
      ) as boolean,
  );
  const hasMore = useAppSelector(
    (state) => !!state.status_lists.getIn(['emoji_reactions', 'next']),
  );

  useEffect(() => {
    dispatch(fetchEmojiReactedStatuses());
  }, [dispatch]);

  const handlePin = useCallback(() => {
    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('EMOJI_REACTIONS', {}));
    }
  }, [dispatch, columnId]);

  const handleMove = useCallback(
    (dir: number) => {
      dispatch(moveColumn(columnId, dir));
    },
    [dispatch, columnId],
  );

  const handleLoadMore = useCallback(() => {
    dispatch(expandEmojiReactedStatuses());
  }, [dispatch]);

  const pinned = !!columnId;

  const emptyMessage = (
    <FormattedMessage
      id='empty_column.emoji_reacted_statuses'
      defaultMessage="You don't have any emoji reacted posts yet. When you emoji react one, it will show up here."
    />
  );

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.heading)}
    >
      <ColumnHeader
        icon='star'
        iconComponent={EmojiReactionIcon}
        title={intl.formatMessage(messages.heading)}
        onPin={handlePin}
        onMove={handleMove}
        pinned={pinned}
        multiColumn={multiColumn}
        scrollTopOnClick
      />

      <StatusList
        trackScroll={!pinned}
        statusIds={statusIds}
        scrollKey={`emoji_reacted_statuses-${columnId}`}
        hasMore={hasMore}
        isLoading={isLoading}
        onLoadMore={handleLoadMore}
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
      />

      <Helmet>
        <title>{intl.formatMessage(messages.heading)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Favourites;
