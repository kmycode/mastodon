import { useCallback, useEffect } from 'react';

import { defineMessages, FormattedMessage, useIntl } from 'react-intl';

import { useParams } from 'react-router-dom';

import type { List as ImmutableList } from 'immutable';

import { ArrowClockwiseIcon } from '@phosphor-icons/react';
import { Helmet } from '@unhead/react/helmet';
import { useDebouncedCallback } from 'use-debounce';

import { ColumnHeader as LegacyColumnHeader } from '@/mastodon/components/column/header';
import {
  ColumnHeader,
  ColumnHeaderButton,
} from '@/mastodon/components/column_header';
import { EmojiView } from '@/mastodon/components/emoji_view';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';
import { isRedesignEnabled } from '@/mastodon/utils/environment';
import RefreshIcon from '@/material-icons/400-24px/refresh.svg?react';
import {
  fetchEmojiReactions,
  expandEmojiReactions,
} from 'mastodon/actions/interactions';
import { Account } from 'mastodon/components/account';
import { Column } from 'mastodon/components/column';
import { Icon } from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import ScrollableList from 'mastodon/components/scrollable_list';

const messages = defineMessages({
  title: {
    id: 'status.emoji_reactions_title',
    defaultMessage: 'Post Emoji Reacted',
  },
  refresh: { id: 'refresh', defaultMessage: 'Refresh' },
});

const EmojiReactions: React.FC<{ multiColumn?: boolean }> = ({
  multiColumn,
}) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();

  const { statusId } = useParams<{ statusId?: string }>();

  const { accountIds, hasMore, isLoading } = useAppSelector((state) => ({
    accountIds: state.user_lists.getIn([
      'emoji_reactioned_by',
      statusId,
      'items',
    ]) as ImmutableList<{ account_id: string; name: string }> | undefined,
    hasMore: !!state.user_lists.getIn([
      'emoji_reactioned_by',
      statusId,
      'next',
    ]),
    isLoading: state.user_lists.getIn(
      ['emoji_reactioned_by', statusId, 'isLoading'],
      true,
    ) as boolean,
  }));

  useEffect(() => {
    if (!accountIds) {
      dispatch(fetchEmojiReactions(statusId));
    }
  }, [accountIds, dispatch, statusId]);

  const handleRefresh = useCallback(() => {
    dispatch(fetchEmojiReactions(statusId));
  }, [dispatch, statusId]);

  const handleLoadMore = useDebouncedCallback(
    () => {
      dispatch(expandEmojiReactions(statusId));
    },
    300,
    {
      leading: true,
    },
  );

  if (!accountIds) {
    return (
      <Column>
        <LoadingIndicator />
      </Column>
    );
  }

  const groups: Record<
    string,
    {
      account_id: string;
      name: string;
      url?: string;
      static_url?: string;
    }[]
  > = {};
  accountIds.forEach((emoji_reaction) => {
    const key = emoji_reaction.account_id;
    const value = emoji_reaction;
    if (!groups[key]) groups[key] = [value];
    else groups[key].push(value);
  });

  const emptyMessage = (
    <FormattedMessage
      id='empty_column.emoji_reactions'
      defaultMessage='No one has reacted with emoji this post yet. When someone does, they will show up here.'
    />
  );

  return (
    <Column bindToDocument={!multiColumn}>
      {isRedesignEnabled() ? (
        <ColumnHeader
          withBackButton
          title={intl.formatMessage(messages.title)}
          extraButtons={
            <ColumnHeaderButton
              icon={ArrowClockwiseIcon}
              onClick={handleRefresh}
            >
              {intl.formatMessage(messages.refresh)}
            </ColumnHeaderButton>
          }
        />
      ) : (
        <LegacyColumnHeader
          showBackButton
          multiColumn={multiColumn}
          extraButton={
            <button
              type='button'
              className='column-header__button'
              title={intl.formatMessage(messages.refresh)}
              aria-label={intl.formatMessage(messages.refresh)}
              onClick={handleRefresh}
            >
              <Icon id='refresh' icon={RefreshIcon} />
            </button>
          }
        />
      )}

      <ScrollableList
        scrollKey='emoji_reactions'
        onLoadMore={handleLoadMore}
        hasMore={hasMore}
        isLoading={isLoading}
        emptyMessage={emptyMessage}
        bindToDocument={!multiColumn}
      >
        {Object.keys(groups).map((key) => (
          <Account
            key={key}
            id={key}
            reference='status'
            hideButtons
            childrenA={
              <div style={{ maxWidth: '100px', display: 'flex' }}>
                {groups[key]?.map((value, index2) => (
                  <EmojiView
                    key={index2}
                    name={value.name}
                    url={value.url}
                    staticUrl={value.static_url}
                  />
                ))}
              </div>
            }
          />
        ))}
      </ScrollableList>

      <Helmet>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default EmojiReactions;
