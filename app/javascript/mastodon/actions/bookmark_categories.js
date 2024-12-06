import api, { getLinks } from '../api';

import { importFetchedStatuses } from './importer';

export const BOOKMARK_CATEGORY_FETCH_REQUEST = 'BOOKMARK_CATEGORY_FETCH_REQUEST';
export const BOOKMARK_CATEGORY_FETCH_SUCCESS = 'BOOKMARK_CATEGORY_FETCH_SUCCESS';
export const BOOKMARK_CATEGORY_FETCH_FAIL    = 'BOOKMARK_CATEGORY_FETCH_FAIL';

export const BOOKMARK_CATEGORIES_FETCH_REQUEST = 'BOOKMARK_CATEGORIES_FETCH_REQUEST';
export const BOOKMARK_CATEGORIES_FETCH_SUCCESS = 'BOOKMARK_CATEGORIES_FETCH_SUCCESS';
export const BOOKMARK_CATEGORIES_FETCH_FAIL    = 'BOOKMARK_CATEGORIES_FETCH_FAIL';

export const BOOKMARK_CATEGORY_DELETE_REQUEST = 'BOOKMARK_CATEGORY_DELETE_REQUEST';
export const BOOKMARK_CATEGORY_DELETE_SUCCESS = 'BOOKMARK_CATEGORY_DELETE_SUCCESS';
export const BOOKMARK_CATEGORY_DELETE_FAIL    = 'BOOKMARK_CATEGORY_DELETE_FAIL';

export const BOOKMARK_CATEGORY_STATUSES_FETCH_REQUEST = 'BOOKMARK_CATEGORY_STATUSES_FETCH_REQUEST';
export const BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS = 'BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS';
export const BOOKMARK_CATEGORY_STATUSES_FETCH_FAIL    = 'BOOKMARK_CATEGORY_STATUSES_FETCH_FAIL';

export const BOOKMARK_CATEGORY_STATUSES_EXPAND_REQUEST = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_REQUEST';
export const BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS';
export const BOOKMARK_CATEGORY_STATUSES_EXPAND_FAIL    = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_FAIL';

export const BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS = 'BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS';
export const BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS = 'BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS';

export const fetchBookmarkCategory = id => (dispatch, getState) => {
  if (getState().getIn(['bookmark_categories', id])) {
    return;
  }

  dispatch(fetchBookmarkCategoryRequest(id));

  api(getState).get(`/api/v1/bookmark_categories/${id}`)
    .then(({ data }) => dispatch(fetchBookmarkCategorySuccess(data)))
    .catch(err => dispatch(fetchBookmarkCategoryFail(id, err)));
};

export const fetchBookmarkCategoryRequest = id => ({
  type: BOOKMARK_CATEGORY_FETCH_REQUEST,
  id,
});

export const fetchBookmarkCategorySuccess = bookmarkCategory => ({
  type: BOOKMARK_CATEGORY_FETCH_SUCCESS,
  bookmarkCategory,
});

export const fetchBookmarkCategoryFail = (id, error) => ({
  type: BOOKMARK_CATEGORY_FETCH_FAIL,
  id,
  error,
});

export const fetchBookmarkCategories = () => (dispatch, getState) => {
  dispatch(fetchBookmarkCategoriesRequest());

  api(getState).get('/api/v1/bookmark_categories')
    .then(({ data }) => dispatch(fetchBookmarkCategoriesSuccess(data)))
    .catch(err => dispatch(fetchBookmarkCategoriesFail(err)));
};

export const fetchBookmarkCategoriesRequest = () => ({
  type: BOOKMARK_CATEGORIES_FETCH_REQUEST,
});

export const fetchBookmarkCategoriesSuccess = bookmarkCategories => ({
  type: BOOKMARK_CATEGORIES_FETCH_SUCCESS,
  bookmarkCategories,
});

export const fetchBookmarkCategoriesFail = error => ({
  type: BOOKMARK_CATEGORIES_FETCH_FAIL,
  error,
});

export const deleteBookmarkCategory = id => (dispatch, getState) => {
  dispatch(deleteBookmarkCategoryRequest(id));

  api(getState).delete(`/api/v1/bookmark_categories/${id}`)
    .then(() => dispatch(deleteBookmarkCategorySuccess(id)))
    .catch(err => dispatch(deleteBookmarkCategoryFail(id, err)));
};

export const deleteBookmarkCategoryRequest = id => ({
  type: BOOKMARK_CATEGORY_DELETE_REQUEST,
  id,
});

export const deleteBookmarkCategorySuccess = id => ({
  type: BOOKMARK_CATEGORY_DELETE_SUCCESS,
  id,
});

export const deleteBookmarkCategoryFail = (id, error) => ({
  type: BOOKMARK_CATEGORY_DELETE_FAIL,
  id,
  error,
});

export const fetchBookmarkCategoryStatuses = bookmarkCategoryId => (dispatch, getState) => {
  dispatch(fetchBookmarkCategoryStatusesRequest(bookmarkCategoryId));

  api(getState).get(`/api/v1/bookmark_categories/${bookmarkCategoryId}/statuses`).then((response) => {
    const next = getLinks(response).refs.find(link => link.rel === 'next');
    dispatch(importFetchedStatuses(response.data));
    dispatch(fetchBookmarkCategoryStatusesSuccess(bookmarkCategoryId, response.data, next ? next.uri : null));
  }).catch(err => dispatch(fetchBookmarkCategoryStatusesFail(bookmarkCategoryId, err)));
};

export const fetchBookmarkCategoryStatusesRequest = id => ({
  type: BOOKMARK_CATEGORY_STATUSES_FETCH_REQUEST,
  id,
});

export const fetchBookmarkCategoryStatusesSuccess = (id, statuses, next) => ({
  type: BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS,
  id,
  statuses,
  next,
});

export const fetchBookmarkCategoryStatusesFail = (id, error) => ({
  type: BOOKMARK_CATEGORY_STATUSES_FETCH_FAIL,
  id,
  error,
});

export function expandBookmarkCategoryStatuses(bookmarkCategoryId) {
  return (dispatch, getState) => {
    const url = getState().getIn(['status_lists', 'bookmark_category_statuses', bookmarkCategoryId, 'next'], null);

    if (url === null || getState().getIn(['status_lists', 'bookmark_category_statuses', bookmarkCategoryId, 'isLoading'])) {
      return;
    }

    dispatch(expandBookmarkCategoryStatusesRequest(bookmarkCategoryId));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedStatuses(response.data));
      dispatch(expandBookmarkCategoryStatusesSuccess(bookmarkCategoryId, response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(expandBookmarkCategoryStatusesFail(bookmarkCategoryId, error));
    });
  };
}

export function expandBookmarkCategoryStatusesRequest(id) {
  return {
    type: BOOKMARK_CATEGORY_STATUSES_EXPAND_REQUEST,
    id,
  };
}

export function expandBookmarkCategoryStatusesSuccess(id, statuses, next) {
  return {
    type: BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS,
    id,
    statuses,
    next,
  };
}

export function expandBookmarkCategoryStatusesFail(id, error) {
  return {
    type: BOOKMARK_CATEGORY_STATUSES_EXPAND_FAIL,
    id,
    error,
  };
}

export function bookmarkCategoryEditorAddSuccess(id, statusId) {
  return {
    type: BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS,
    id,
    statusId,
  };
}

export function bookmarkCategoryEditorRemoveSuccess(id, statusId) {
  return {
    type: BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS,
    id,
    statusId,
  };
}

