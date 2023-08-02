import api, { getLinks } from '../api';

import { importFetchedStatuses } from './importer';

export const EMOJI_REACTED_STATUSES_FETCH_REQUEST = 'EMOJI_REACTED_STATUSES_FETCH_REQUEST';
export const EMOJI_REACTED_STATUSES_FETCH_SUCCESS = 'EMOJI_REACTED_STATUSES_FETCH_SUCCESS';
export const EMOJI_REACTED_STATUSES_FETCH_FAIL    = 'EMOJI_REACTED_STATUSES_FETCH_FAIL';

export const EMOJI_REACTED_STATUSES_EXPAND_REQUEST = 'EMOJI_REACTED_STATUSES_EXPAND_REQUEST';
export const EMOJI_REACTED_STATUSES_EXPAND_SUCCESS = 'EMOJI_REACTED_STATUSES_EXPAND_SUCCESS';
export const EMOJI_REACTED_STATUSES_EXPAND_FAIL    = 'EMOJI_REACTED_STATUSES_EXPAND_FAIL';

export function fetchEmojiReactedStatuses() {
  return (dispatch, getState) => {
    if (getState().getIn(['status_lists', 'emoji_reactions', 'isLoading'])) {
      return;
    }

    dispatch(fetchEmojiReactedStatusesRequest());

    api(getState).get('/api/v1/emoji_reactions').then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedStatuses(response.data));
      dispatch(fetchEmojiReactedStatusesSuccess(response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(fetchEmojiReactedStatusesFail(error));
    });
  };
}

export function fetchEmojiReactedStatusesRequest() {
  return {
    type: EMOJI_REACTED_STATUSES_FETCH_REQUEST,
    skipLoading: true,
  };
}

export function fetchEmojiReactedStatusesSuccess(statuses, next) {
  return {
    type: EMOJI_REACTED_STATUSES_FETCH_SUCCESS,
    statuses,
    next,
    skipLoading: true,
  };
}

export function fetchEmojiReactedStatusesFail(error) {
  return {
    type: EMOJI_REACTED_STATUSES_FETCH_FAIL,
    error,
    skipLoading: true,
  };
}

export function expandEmojiReactedStatuses() {
  return (dispatch, getState) => {
    const url = getState().getIn(['status_lists', 'emoji_reactions', 'next'], null);

    if (url === null || getState().getIn(['status_lists', 'emoji_reactions', 'isLoading'])) {
      return;
    }

    dispatch(expandEmojiReactedStatusesRequest());

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedStatuses(response.data));
      dispatch(expandEmojiReactedStatusesSuccess(response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(expandEmojiReactedStatusesFail(error));
    });
  };
}

export function expandEmojiReactedStatusesRequest() {
  return {
    type: EMOJI_REACTED_STATUSES_EXPAND_REQUEST,
  };
}

export function expandEmojiReactedStatusesSuccess(statuses, next) {
  return {
    type: EMOJI_REACTED_STATUSES_EXPAND_SUCCESS,
    statuses,
    next,
  };
}

export function expandEmojiReactedStatusesFail(error) {
  return {
    type: EMOJI_REACTED_STATUSES_EXPAND_FAIL,
    error,
  };
}
