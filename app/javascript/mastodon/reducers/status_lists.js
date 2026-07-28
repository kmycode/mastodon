import { Map as ImmutableMap, OrderedSet as ImmutableOrderedSet } from 'immutable';

import { BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS, BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS, BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS, BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS } from 'mastodon/actions/bookmark_categories';
import { CIRCLE_STATUSES_EXPAND_SUCCESS, CIRCLE_STATUSES_FETCH_SUCCESS } from 'mastodon/actions/circles';
import { COMPOSE_WITH_CIRCLE_SUCCESS } from 'mastodon/actions/compose';

import {
  blockAccountSuccess,
  muteAccountSuccess,
} from '../actions/accounts';
import {
  BOOKMARKED_STATUSES_FETCH_REQUEST,
  BOOKMARKED_STATUSES_FETCH_SUCCESS,
  BOOKMARKED_STATUSES_FETCH_FAIL,
  BOOKMARKED_STATUSES_EXPAND_REQUEST,
  BOOKMARKED_STATUSES_EXPAND_SUCCESS,
  BOOKMARKED_STATUSES_EXPAND_FAIL,
} from '../actions/bookmarks';
import {
  EMOJI_REACTED_STATUSES_FETCH_REQUEST,
  EMOJI_REACTED_STATUSES_FETCH_SUCCESS,
  EMOJI_REACTED_STATUSES_FETCH_FAIL,
  EMOJI_REACTED_STATUSES_EXPAND_REQUEST,
  EMOJI_REACTED_STATUSES_EXPAND_SUCCESS,
  EMOJI_REACTED_STATUSES_EXPAND_FAIL,
} from '../actions/emoji_reactions';
import {
  FAVOURITED_STATUSES_FETCH_REQUEST,
  FAVOURITED_STATUSES_FETCH_SUCCESS,
  FAVOURITED_STATUSES_FETCH_FAIL,
  FAVOURITED_STATUSES_EXPAND_REQUEST,
  FAVOURITED_STATUSES_EXPAND_SUCCESS,
  FAVOURITED_STATUSES_EXPAND_FAIL,
} from '../actions/favourites';
import {
  FAVOURITE_SUCCESS,
  UNFAVOURITE_SUCCESS,
  EMOJIREACT_SUCCESS,
  UNEMOJIREACT_SUCCESS,
  BOOKMARK_SUCCESS,
  UNBOOKMARK_SUCCESS,
  PIN_SUCCESS,
  UNPIN_SUCCESS,
} from '../actions/interactions';
import {
  fetchQuotes
} from '../actions/interactions_typed';
import {
  PINNED_STATUSES_FETCH_SUCCESS,
} from '../actions/pin_statuses';
import {
  TRENDS_STATUSES_FETCH_REQUEST,
  TRENDS_STATUSES_FETCH_SUCCESS,
  TRENDS_STATUSES_FETCH_FAIL,
  TRENDS_STATUSES_EXPAND_REQUEST,
  TRENDS_STATUSES_EXPAND_SUCCESS,
  TRENDS_STATUSES_EXPAND_FAIL,
} from '../actions/trends';

const initialState = ImmutableMap({
  favourites: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
  }),
  emoji_reactions: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
  }),
  bookmarks: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
  }),
  pins: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
  }),
  trending: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
  }),
  circle_statuses: ImmutableMap(),
  bookmark_category_statuses: ImmutableMap(),
  quotes: ImmutableMap({
    next: null,
    loaded: false,
    items: ImmutableOrderedSet(),
    statusId: null,
  }),
});

const normalizeList = (state, listType, statuses, next) => {
  if (Array.isArray(listType)) {
    if (state.getIn(listType)) {
      return state.updateIn(listType, listMap => {
        return listMap.withMutations(map => {
          map.set('next', next);
          map.set('loaded', true);
          map.set('isLoading', false);
          map.set('items', ImmutableOrderedSet(statuses.map(item => item.id)));
        });
      });
    } else {
      return state.setIn(listType, ImmutableMap({
        next: next,
        loaded: true,
        isLoading: false,
        items: ImmutableOrderedSet(statuses.map(item => item.id)),
      }));
    }
  }

  return state.update(listType, listMap => listMap.withMutations(map => {
    map.set('next', next);
    map.set('loaded', true);
    map.set('isLoading', false);
    map.set('items', ImmutableOrderedSet(statuses.map(item => item.id)));
  }));
};

const appendToList = (state, listType, statuses, next) => {
  if (Array.isArray(listType)) {
    return state.updateIn(listType, listMap => listMap.withMutations(map => {
      map.set('next', next);
      map.set('isLoading', false);
      map.set('items', map.get('items').union(statuses.map(item => item.id)));
    }));
  }

  return state.update(listType, listMap => listMap.withMutations(map => {
    map.set('next', next);
    map.set('isLoading', false);
    map.set('items', map.get('items').union(statuses.map(item => item.id)));
  }));
};

const prependOneToList = (state, listType, status) => {
  return prependOneToListById(state, listType, status.get('id'));
};

const prependOneToListById = (state, listType, statusId) => {
  if (Array.isArray(listType)) {
    if (!state.getIn(listType)) return state;

    return state.updateIn(listType, item => item.withMutations(map => {
      if (map.get('items')) {
        map.update('items', list => ImmutableOrderedSet([statusId]).union(list));
      }
    }));
  }

  return state.updateIn([listType, 'items'], (list) => {
    if (list.includes(statusId)) {
      return list;
    } else {
      return ImmutableOrderedSet([statusId]).union(list);
    }
  });
};

const removeOneFromList = (state, listType, status) => {
  return state.updateIn([listType, 'items'], (list) => list.delete(status.get('id')));
};

const removeOneFromListById = (state, listType, statusId) => {
  if (Array.isArray(listType)) {
    if (!state.getIn(listType)) return state;

    return state.updateIn(listType, item => item.withMutations(map => {
      if (map.get('items')) {
        map.update('items', list => list.delete(statusId));
      }
    }));
  }
  
  return state.update(listType, item => item.withMutations(map => {
    if (map.get('items')) {
      map.update('items', list => list.delete(statusId));
    }
  }));
};

const removeOneFromAllBookmarkCategoriesById = (state, statusId) => {
  let s = state;
  state.get('bookmark_category_statuses').forEach((category) => {
    s = s.updateIn(['bookmark_category_statuses', category.get('id'), 'items'], list => list?.delete(statusId));
  });
  return s;
};

/** @type {import('@reduxjs/toolkit').Reducer<typeof initialState>} */
export default function statusLists(state = initialState, action) {
  switch(action.type) {
  case FAVOURITED_STATUSES_FETCH_REQUEST:
  case FAVOURITED_STATUSES_EXPAND_REQUEST:
    return state.setIn(['favourites', 'isLoading'], true);
  case FAVOURITED_STATUSES_FETCH_FAIL:
  case FAVOURITED_STATUSES_EXPAND_FAIL:
    return state.setIn(['favourites', 'isLoading'], false);
  case FAVOURITED_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, 'favourites', action.statuses, action.next);
  case FAVOURITED_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, 'favourites', action.statuses, action.next);
  case EMOJI_REACTED_STATUSES_FETCH_REQUEST:
  case EMOJI_REACTED_STATUSES_EXPAND_REQUEST:
    return state.setIn(['emoji_reactions', 'isLoading'], true);
  case EMOJI_REACTED_STATUSES_FETCH_FAIL:
  case EMOJI_REACTED_STATUSES_EXPAND_FAIL:
    return state.setIn(['emoji_reactions', 'isLoading'], false);
  case EMOJI_REACTED_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, 'emoji_reactions', action.statuses, action.next);
  case EMOJI_REACTED_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, 'emoji_reactions', action.statuses, action.next);
  case CIRCLE_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, ['circle_statuses', action.id], action.statuses, action.next);
  case CIRCLE_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, ['circle_statuses', action.id], action.statuses, action.next);
  case COMPOSE_WITH_CIRCLE_SUCCESS:
    return prependOneToListById(state, ['circle_statuses', action.circleId], action.statusId);
  case BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, ['bookmark_category_statuses', action.id], action.statuses, action.next);
  case BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, ['bookmark_category_statuses', action.id], action.statuses, action.next);
  case BOOKMARKED_STATUSES_FETCH_REQUEST:
  case BOOKMARKED_STATUSES_EXPAND_REQUEST:
    return state.setIn(['bookmarks', 'isLoading'], true);
  case BOOKMARKED_STATUSES_FETCH_FAIL:
  case BOOKMARKED_STATUSES_EXPAND_FAIL:
    return state.setIn(['bookmarks', 'isLoading'], false);
  case BOOKMARKED_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, 'bookmarks', action.statuses, action.next);
  case BOOKMARKED_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, 'bookmarks', action.statuses, action.next);
  case TRENDS_STATUSES_FETCH_REQUEST:
  case TRENDS_STATUSES_EXPAND_REQUEST:
    return state.setIn(['trending', 'isLoading'], true);
  case TRENDS_STATUSES_FETCH_FAIL:
  case TRENDS_STATUSES_EXPAND_FAIL:
    return state.setIn(['trending', 'isLoading'], false);
  case TRENDS_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, 'trending', action.statuses, action.next);
  case TRENDS_STATUSES_EXPAND_SUCCESS:
    return appendToList(state, 'trending', action.statuses, action.next);
  case FAVOURITE_SUCCESS:
    return prependOneToList(state, 'favourites', action.status);
  case UNFAVOURITE_SUCCESS:
    return removeOneFromList(state, 'favourites', action.status);
  case EMOJIREACT_SUCCESS:
    return prependOneToList(state, 'emoji_reactions', action.status);
  case UNEMOJIREACT_SUCCESS:
    return removeOneFromList(state, 'emoji_reactions', action.status);
  case BOOKMARK_SUCCESS:
    return prependOneToList(state, 'bookmarks', action.status);
  case BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS:
  {
    const s = prependOneToListById(state, 'bookmarks', action.statusId);
    return prependOneToListById(s, ['bookmark_category_statuses', action.id], action.statusId);
  }
  case BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS:
    return removeOneFromListById(state, ['bookmark_category_statuses', action.id], action.statusId);
  case UNBOOKMARK_SUCCESS:
  {
    const s = removeOneFromList(state, 'bookmarks', action.status);
    return removeOneFromAllBookmarkCategoriesById(s, action.statusId);
  }
  case PINNED_STATUSES_FETCH_SUCCESS:
    return normalizeList(state, 'pins', action.statuses, action.next);
  case PIN_SUCCESS:
    return prependOneToList(state, 'pins', action.status);
  case UNPIN_SUCCESS:
    return removeOneFromList(state, 'pins', action.status);
  case blockAccountSuccess.type:
  case muteAccountSuccess.type:
    return state.updateIn(['trending', 'items'], ImmutableOrderedSet(), list => list.filterNot(statusId => action.payload.statuses.getIn([statusId, 'account']) === action.payload.relationship.id));
  default:
    if (fetchQuotes.fulfilled.match(action))
      return normalizeList(state, 'quotes', action.payload.statuses, action.payload.next).set('statusId', action.meta.arg.statusId);
    else if (fetchQuotes.pending.match(action))
      return state.setIn(['quotes', 'isLoading'], true).setIn(['quotes', 'statusId'], action.meta.arg.statusId);
    else if (fetchQuotes.rejected.match(action))
      return state.setIn(['quotes', 'isLoading'], false).setIn(['quotes', 'statusId'], action.meta.arg.statusId);
    else
      return state;
  }
}
