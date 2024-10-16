import { boostModal } from 'mastodon/initial_state';

import api, { getLinks } from '../api';

import { fetchRelationships } from './accounts';
import { importFetchedAccounts, importFetchedStatus, importFetchedStatuses } from './importer';
import { unreblog, reblog } from './interactions_typed';
import { openModal } from './modal';

export const REBLOGS_EXPAND_REQUEST = 'REBLOGS_EXPAND_REQUEST';
export const REBLOGS_EXPAND_SUCCESS = 'REBLOGS_EXPAND_SUCCESS';
export const REBLOGS_EXPAND_FAIL = 'REBLOGS_EXPAND_FAIL';

export const FAVOURITE_REQUEST = 'FAVOURITE_REQUEST';
export const FAVOURITE_SUCCESS = 'FAVOURITE_SUCCESS';
export const FAVOURITE_FAIL    = 'FAVOURITE_FAIL';

export const EMOJIREACT_REQUEST = 'EMOJIREACT_REQUEST';
export const EMOJIREACT_SUCCESS = 'EMOJIREACT_SUCCESS';
export const EMOJIREACT_FAIL    = 'EMOJIREACT_FAIL';

export const UNFAVOURITE_REQUEST = 'UNFAVOURITE_REQUEST';
export const UNFAVOURITE_SUCCESS = 'UNFAVOURITE_SUCCESS';
export const UNFAVOURITE_FAIL    = 'UNFAVOURITE_FAIL';

export const UNEMOJIREACT_REQUEST = 'UNEMOJIREACT_REQUEST';
export const UNEMOJIREACT_SUCCESS = 'UNEMOJIREACT_SUCCESS';
export const UNEMOJIREACT_FAIL    = 'UNEMOJIREACT_FAIL';

export const REBLOGS_FETCH_REQUEST = 'REBLOGS_FETCH_REQUEST';
export const REBLOGS_FETCH_SUCCESS = 'REBLOGS_FETCH_SUCCESS';
export const REBLOGS_FETCH_FAIL    = 'REBLOGS_FETCH_FAIL';

export const FAVOURITES_FETCH_REQUEST = 'FAVOURITES_FETCH_REQUEST';
export const FAVOURITES_FETCH_SUCCESS = 'FAVOURITES_FETCH_SUCCESS';
export const FAVOURITES_FETCH_FAIL    = 'FAVOURITES_FETCH_FAIL';

export const FAVOURITES_EXPAND_REQUEST = 'FAVOURITES_EXPAND_REQUEST';
export const FAVOURITES_EXPAND_SUCCESS = 'FAVOURITES_EXPAND_SUCCESS';
export const FAVOURITES_EXPAND_FAIL    = 'FAVOURITES_EXPAND_FAIL';

export const STATUS_REFERENCES_FETCH_REQUEST = 'STATUS_REFERENCES_FETCH_REQUEST';
export const STATUS_REFERENCES_FETCH_SUCCESS = 'STATUS_REFERENCES_FETCH_SUCCESS';
export const STATUS_REFERENCES_FETCH_FAIL    = 'STATUS_REFERENCES_FETCH_FAIL';

export const EMOJI_REACTIONS_FETCH_REQUEST = 'EMOJI_REACTIONS_FETCH_REQUEST';
export const EMOJI_REACTIONS_FETCH_SUCCESS = 'EMOJI_REACTIONS_FETCH_SUCCESS';
export const EMOJI_REACTIONS_FETCH_FAIL    = 'EMOJI_REACTIONS_FETCH_FAIL';

export const EMOJI_REACTIONS_EXPAND_REQUEST = 'EMOJI_REACTIONS_EXPAND_REQUEST';
export const EMOJI_REACTIONS_EXPAND_SUCCESS = 'EMOJI_REACTIONS_EXPAND_SUCCESS';
export const EMOJI_REACTIONS_EXPAND_FAIL    = 'EMOJI_REACTIONS_EXPAND_FAIL';

export const PIN_REQUEST = 'PIN_REQUEST';
export const PIN_SUCCESS = 'PIN_SUCCESS';
export const PIN_FAIL    = 'PIN_FAIL';

export const UNPIN_REQUEST = 'UNPIN_REQUEST';
export const UNPIN_SUCCESS = 'UNPIN_SUCCESS';
export const UNPIN_FAIL    = 'UNPIN_FAIL';

export const BOOKMARK_REQUEST = 'BOOKMARK_REQUEST';
export const BOOKMARK_SUCCESS = 'BOOKMARKED_SUCCESS';
export const BOOKMARK_FAIL    = 'BOOKMARKED_FAIL';

export const UNBOOKMARK_REQUEST = 'UNBOOKMARKED_REQUEST';
export const UNBOOKMARK_SUCCESS = 'UNBOOKMARKED_SUCCESS';
export const UNBOOKMARK_FAIL    = 'UNBOOKMARKED_FAIL';

export const MENTIONED_USERS_FETCH_REQUEST = 'MENTIONED_USERS_FETCH_REQUEST';
export const MENTIONED_USERS_FETCH_SUCCESS = 'MENTIONED_USERS_FETCH_SUCCESS';
export const MENTIONED_USERS_FETCH_FAIL    = 'MENTIONED_USERS_FETCH_FAIL';

export const MENTIONED_USERS_EXPAND_REQUEST = 'MENTIONED_USERS_EXPAND_REQUEST';
export const MENTIONED_USERS_EXPAND_SUCCESS = 'MENTIONED_USERS_EXPAND_SUCCESS';
export const MENTIONED_USERS_EXPAND_FAIL    = 'MENTIONED_USERS_EXPAND_FAIL';

export * from "./interactions_typed";

export function favourite(status) {
  return function (dispatch) {
    dispatch(favouriteRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/favourite`).then(function (response) {
      dispatch(importFetchedStatus(response.data));
      dispatch(favouriteSuccess(status));
    }).catch(function (error) {
      dispatch(favouriteFail(status, error));
    });
  };
}

export function unfavourite(status) {
  return (dispatch) => {
    dispatch(unfavouriteRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/unfavourite`).then(response => {
      dispatch(importFetchedStatus(response.data));
      dispatch(unfavouriteSuccess(status));
    }).catch(error => {
      dispatch(unfavouriteFail(status, error));
    });
  };
}

export function favouriteRequest(status) {
  return {
    type: FAVOURITE_REQUEST,
    status: status,
    skipLoading: true,
  };
}

export function favouriteSuccess(status) {
  return {
    type: FAVOURITE_SUCCESS,
    status: status,
    skipLoading: true,
  };
}

export function favouriteFail(status, error) {
  return {
    type: FAVOURITE_FAIL,
    status: status,
    error: error,
    skipLoading: true,
  };
}

export function unfavouriteRequest(status) {
  return {
    type: UNFAVOURITE_REQUEST,
    status: status,
    skipLoading: true,
  };
}

export function unfavouriteSuccess(status) {
  return {
    type: UNFAVOURITE_SUCCESS,
    status: status,
    skipLoading: true,
  };
}

export function unfavouriteFail(status, error) {
  return {
    type: UNFAVOURITE_FAIL,
    status: status,
    error: error,
    skipLoading: true,
  };
}

export function emojiReact(status, emoji) {
  return function (dispatch, getState) {
    dispatch(emojiReactRequest(status, emoji));

    const api_emoji = typeof emoji !== 'string' ? (emoji.custom ? (emoji.name + (emoji.domain || '')) : emoji.native) : emoji;

    api(getState).post(`/api/v1/statuses/${status.get('id')}/emoji_reactions`, { emoji: api_emoji }).then(function (response) {
      dispatch(importFetchedStatus(response.data));
      dispatch(emojiReactSuccess(status, emoji));
    }).catch(function (error) {
      dispatch(emojiReactFail(status, emoji, error));
    });
  };
}

export function unEmojiReact(status, emoji) {
  return (dispatch, getState) => {
    dispatch(unEmojiReactRequest(status, emoji));

    api(getState).post(`/api/v1/statuses/${status.get('id')}/emoji_unreaction`, { emoji }).then((response) => {
      // TODO: do not update because this api has a bug
      dispatch(importFetchedStatus(response.data));
      dispatch(unEmojiReactSuccess(status, emoji));
    }).catch(error => {
      dispatch(unEmojiReactFail(status, emoji, error));
    });
  };
}

export function emojiReactRequest(status, emoji) {
  return {
    type: EMOJIREACT_REQUEST,
    status: status,
    emoji: emoji,
    skipLoading: true,
  };
}

export function emojiReactSuccess(status, emoji) {
  return {
    type: EMOJIREACT_SUCCESS,
    status: status,
    emoji: emoji,
    skipLoading: true,
  };
}

export function emojiReactFail(status, emoji, error) {
  return {
    type: EMOJIREACT_FAIL,
    status: status,
    emoji: emoji,
    error: error,
    skipLoading: true,
  };
}

export function unEmojiReactRequest(status, emoji) {
  return {
    type: UNEMOJIREACT_REQUEST,
    status: status,
    emoji: emoji,
    skipLoading: true,
  };
}

export function unEmojiReactSuccess(status, emoji) {
  return {
    type: UNEMOJIREACT_SUCCESS,
    status: status,
    emoji: emoji,
    skipLoading: true,
  };
}

export function unEmojiReactFail(status, emoji, error) {
  return {
    type: UNEMOJIREACT_FAIL,
    status: status,
    emoji: emoji,
    error: error,
    skipLoading: true,
  };
}

export function bookmark(status) {
  return function (dispatch) {
    dispatch(bookmarkRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/bookmark`).then(function (response) {
      dispatch(importFetchedStatus(response.data));
      dispatch(bookmarkSuccess(status, response.data));
    }).catch(function (error) {
      dispatch(bookmarkFail(status, error));
    });
  };
}

export function unbookmark(status) {
  return (dispatch) => {
    dispatch(unbookmarkRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/unbookmark`).then(response => {
      dispatch(importFetchedStatus(response.data));
      dispatch(unbookmarkSuccess(status, response.data));
    }).catch(error => {
      dispatch(unbookmarkFail(status, error));
    });
  };
}

export function bookmarkRequest(status) {
  return {
    type: BOOKMARK_REQUEST,
    status: status,
  };
}

export function bookmarkSuccess(status, response) {
  return {
    type: BOOKMARK_SUCCESS,
    status: status,
    response: response,
  };
}

export function bookmarkFail(status, error) {
  return {
    type: BOOKMARK_FAIL,
    status: status,
    error: error,
  };
}

export function unbookmarkRequest(status) {
  return {
    type: UNBOOKMARK_REQUEST,
    status: status,
  };
}

export function unbookmarkSuccess(status, response) {
  return {
    type: UNBOOKMARK_SUCCESS,
    status: status,
    response: response,
  };
}

export function unbookmarkFail(status, error) {
  return {
    type: UNBOOKMARK_FAIL,
    status: status,
    error: error,
  };
}

export function fetchReblogs(id) {
  return (dispatch) => {
    dispatch(fetchReblogsRequest(id));

    api().get(`/api/v1/statuses/${id}/reblogged_by`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchReblogsSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(fetchReblogsFail(id, error));
    });
  };
}

export function fetchReblogsRequest(id) {
  return {
    type: REBLOGS_FETCH_REQUEST,
    id,
  };
}

export function fetchReblogsSuccess(id, accounts, next) {
  return {
    type: REBLOGS_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function fetchReblogsFail(id, error) {
  return {
    type: REBLOGS_FETCH_FAIL,
    id,
    error,
  };
}

export function expandReblogs(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'reblogged_by', id, 'next']);
    if (url === null) {
      return;
    }

    dispatch(expandReblogsRequest(id));

    api().get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(expandReblogsSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => dispatch(expandReblogsFail(id, error)));
  };
}

export function expandReblogsRequest(id) {
  return {
    type: REBLOGS_EXPAND_REQUEST,
    id,
  };
}

export function expandReblogsSuccess(id, accounts, next) {
  return {
    type: REBLOGS_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function expandReblogsFail(id, error) {
  return {
    type: REBLOGS_EXPAND_FAIL,
    id,
    error,
  };
}

export function fetchFavourites(id) {
  return (dispatch) => {
    dispatch(fetchFavouritesRequest(id));

    api().get(`/api/v1/statuses/${id}/favourited_by`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchFavouritesSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(fetchFavouritesFail(id, error));
    });
  };
}

export function fetchFavouritesRequest(id) {
  return {
    type: FAVOURITES_FETCH_REQUEST,
    id,
  };
}

export function fetchFavouritesSuccess(id, accounts, next) {
  return {
    type: FAVOURITES_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function fetchFavouritesFail(id, error) {
  return {
    type: FAVOURITES_FETCH_FAIL,
    id,
    error,
  };
}

export function expandFavourites(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'favourited_by', id, 'next']);
    if (url === null) {
      return;
    }

    dispatch(expandFavouritesRequest(id));

    api().get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(expandFavouritesSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => dispatch(expandFavouritesFail(id, error)));
  };
}

export function expandFavouritesRequest(id) {
  return {
    type: FAVOURITES_EXPAND_REQUEST,
    id,
  };
}

export function expandFavouritesSuccess(id, accounts, next) {
  return {
    type: FAVOURITES_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function expandFavouritesFail(id, error) {
  return {
    type: FAVOURITES_EXPAND_FAIL,
    id,
    error,
  };
}

export function fetchEmojiReactions(id) {
  return (dispatch, getState) => {
    dispatch(fetchEmojiReactionsRequest(id));

    api(getState).get(`/api/v1/statuses/${id}/emoji_reactioned_by`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data.map((er) => er.account)));
      dispatch(fetchEmojiReactionsSuccess(id, response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(fetchEmojiReactionsFail(id, error));
    });
  };
}

export function fetchEmojiReactionsRequest(id) {
  return {
    type: EMOJI_REACTIONS_FETCH_REQUEST,
    id,
  };
}

export function fetchEmojiReactionsSuccess(id, accounts, next) {
  return {
    type: EMOJI_REACTIONS_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function fetchEmojiReactionsFail(id, error) {
  return {
    type: EMOJI_REACTIONS_FETCH_FAIL,
    error,
  };
}

export function expandEmojiReactions(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'emoji_reactioned_by', id, 'next']);
    if (url === null) {
      return;
    }

    dispatch(expandEmojiReactionsRequest(id));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data.map((er) => er.account)));
      dispatch(expandEmojiReactionsSuccess(id, response.data, next ? next.uri : null));
    }).catch(error => dispatch(expandEmojiReactionsFail(id, error)));
  };
}

export function expandEmojiReactionsRequest(id) {
  return {
    type: EMOJI_REACTIONS_EXPAND_REQUEST,
    id,
  };
}

export function expandEmojiReactionsSuccess(id, accounts, next) {
  return {
    type: EMOJI_REACTIONS_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function expandEmojiReactionsFail(id, error) {
  return {
    type: EMOJI_REACTIONS_EXPAND_FAIL,
    id,
    error,
  };
}

export function fetchStatusReferences(id) {
  return (dispatch, getState) => {
    dispatch(fetchStatusReferencesRequest(id));

    api(getState).get(`/api/v1/statuses/${id}/referred_by`).then(response => {
      dispatch(importFetchedStatuses(response.data));
      dispatch(fetchStatusReferencesSuccess(id, response.data));
    }).catch(error => {
      dispatch(fetchStatusReferencesFail(id, error));
    });
  };
}

export function fetchStatusReferencesRequest(id) {
  return {
    type: STATUS_REFERENCES_FETCH_REQUEST,
    id,
  };
}

export function fetchStatusReferencesSuccess(id, statuses) {
  return {
    type: STATUS_REFERENCES_FETCH_SUCCESS,
    id,
    statuses,
  };
}

export function fetchStatusReferencesFail(id, error) {
  return {
    type: STATUS_REFERENCES_FETCH_FAIL,
    error,
  };
}

export function pin(status) {
  return (dispatch) => {
    dispatch(pinRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/pin`).then(response => {
      dispatch(importFetchedStatus(response.data));
      dispatch(pinSuccess(status));
    }).catch(error => {
      dispatch(pinFail(status, error));
    });
  };
}

export function pinRequest(status) {
  return {
    type: PIN_REQUEST,
    status,
    skipLoading: true,
  };
}

export function pinSuccess(status) {
  return {
    type: PIN_SUCCESS,
    status,
    skipLoading: true,
  };
}

export function pinFail(status, error) {
  return {
    type: PIN_FAIL,
    status,
    error,
    skipLoading: true,
  };
}

export function unpin (status) {
  return (dispatch) => {
    dispatch(unpinRequest(status));

    api().post(`/api/v1/statuses/${status.get('id')}/unpin`).then(response => {
      dispatch(importFetchedStatus(response.data));
      dispatch(unpinSuccess(status));
    }).catch(error => {
      dispatch(unpinFail(status, error));
    });
  };
}

export function unpinRequest(status) {
  return {
    type: UNPIN_REQUEST,
    status,
    skipLoading: true,
  };
}

export function unpinSuccess(status) {
  return {
    type: UNPIN_SUCCESS,
    status,
    skipLoading: true,
  };
}

export function unpinFail(status, error) {
  return {
    type: UNPIN_FAIL,
    status,
    error,
    skipLoading: true,
  };
}

export function fetchMentionedUsers(id) {
  return (dispatch, getState) => {
    dispatch(fetchMentionedUsersRequest(id));

    api(getState).get(`/api/v1/statuses/${id}/mentioned_by`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchMentionedUsersSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(fetchMentionedUsersFail(id, error));
    });
  };
}

export function fetchMentionedUsersRequest(id) {
  return {
    type: MENTIONED_USERS_FETCH_REQUEST,
    id,
  };
}

export function fetchMentionedUsersSuccess(id, accounts, next) {
  return {
    type: MENTIONED_USERS_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function fetchMentionedUsersFail(id, error) {
  return {
    type: MENTIONED_USERS_FETCH_FAIL,
    id,
    error,
  };
}

export function expandMentionedUsers(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'mentioned_users', id, 'next']);
    if (url === null) {
      return;
    }

    dispatch(expandMentionedUsersRequest(id));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(expandMentionedUsersSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => dispatch(expandMentionedUsersFail(id, error)));
  };
}

export function expandMentionedUsersRequest(id) {
  return {
    type: MENTIONED_USERS_EXPAND_REQUEST,
    id,
  };
}

export function expandMentionedUsersSuccess(id, accounts, next) {
  return {
    type: MENTIONED_USERS_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
}

export function expandMentionedUsersFail(id, error) {
  return {
    type: MENTIONED_USERS_EXPAND_FAIL,
    id,
    error,
  };
}

function toggleReblogWithoutConfirmation(status, visibility) {
  return (dispatch) => {
    if (status.get('reblogged')) {
      dispatch(unreblog({ statusId: status.get('id') }));
    } else {
      dispatch(reblog({ statusId: status.get('id'), visibility }));
    }
  };
}

export function toggleReblog(statusId, skipModal = false, forceModal = false) {
  return (dispatch, getState) => {
    const state = getState();
    let status = state.statuses.get(statusId);

    if (!status)
      return;

    // The reblog modal expects a pre-filled account in status
    // TODO: fix this by having the reblog modal get a statusId and do the work itself
    status = status.set('account', state.accounts.get(status.get('account')));

    if ((boostModal && !skipModal) || (forceModal && !status.get('reblogged'))) {
      dispatch(openModal({ modalType: 'BOOST', modalProps: { status, onReblog: (status, privacy) => dispatch(toggleReblogWithoutConfirmation(status, privacy)) } }));
    } else {
      dispatch(toggleReblogWithoutConfirmation(status));
    }
  };
}

export function toggleFavourite(statusId) {
  return (dispatch, getState) => {
    const state = getState();
    const status = state.statuses.get(statusId);

    if (!status)
      return;

    if (status.get('favourited')) {
      dispatch(unfavourite(status));
    } else {
      dispatch(favourite(status));
    }
  };
}
