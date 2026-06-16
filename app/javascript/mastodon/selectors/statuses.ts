import type { OrderedSet as ImmutableOrderedSet } from 'immutable';
import { List as ImmutableList } from 'immutable';

import { createAppSelector } from 'mastodon/store';

import type { StatusShape } from '../models/status';

export const getStatusList = createAppSelector(
  [
    (
      state,
      type:
        | 'favourites'
        | 'bookmarks'
        | 'pins'
        | 'trending'
        | 'emoji_reactions',
    ) =>
      state.status_lists.getIn([type, 'items']) as ImmutableOrderedSet<string>,
  ],
  (items) => items.toList(),
);

export const getSubStatusList = createAppSelector(
  [
    (state, type: 'bookmark_category' | 'circle', id: string) =>
      state.status_lists.getIn([
        `${type}_statuses`,
        id,
        'items',
      ]) as ImmutableOrderedSet<string> | null,
  ],
  (items) => (items ? items.toList() : ImmutableList()),
);

export const selectPlainStatus = createAppSelector(
  [(state, statusId: string) => state.statuses.get(statusId)],
  (status) => {
    if (!status) {
      return null;
    }
    return status.toJS() as unknown as StatusShape;
  },
);
