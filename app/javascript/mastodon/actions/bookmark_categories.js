import { bookmarkCategoryNeeded } from 'mastodon/initial_state';
import { makeGetStatus } from 'mastodon/selectors';

import api, { getLinks } from '../api';

import { importFetchedStatuses } from './importer';
import { unbookmark } from './interactions';

export const BOOKMARK_CATEGORY_FETCH_REQUEST = 'BOOKMARK_CATEGORY_FETCH_REQUEST';
export const BOOKMARK_CATEGORY_FETCH_SUCCESS = 'BOOKMARK_CATEGORY_FETCH_SUCCESS';
export const BOOKMARK_CATEGORY_FETCH_FAIL    = 'BOOKMARK_CATEGORY_FETCH_FAIL';

export const BOOKMARK_CATEGORIES_FETCH_REQUEST = 'BOOKMARK_CATEGORIES_FETCH_REQUEST';
export const BOOKMARK_CATEGORIES_FETCH_SUCCESS = 'BOOKMARK_CATEGORIES_FETCH_SUCCESS';
export const BOOKMARK_CATEGORIES_FETCH_FAIL    = 'BOOKMARK_CATEGORIES_FETCH_FAIL';

export const BOOKMARK_CATEGORY_EDITOR_TITLE_CHANGE = 'BOOKMARK_CATEGORY_EDITOR_TITLE_CHANGE';
export const BOOKMARK_CATEGORY_EDITOR_RESET        = 'BOOKMARK_CATEGORY_EDITOR_RESET';
export const BOOKMARK_CATEGORY_EDITOR_SETUP        = 'BOOKMARK_CATEGORY_EDITOR_SETUP';

export const BOOKMARK_CATEGORY_CREATE_REQUEST = 'BOOKMARK_CATEGORY_CREATE_REQUEST';
export const BOOKMARK_CATEGORY_CREATE_SUCCESS = 'BOOKMARK_CATEGORY_CREATE_SUCCESS';
export const BOOKMARK_CATEGORY_CREATE_FAIL    = 'BOOKMARK_CATEGORY_CREATE_FAIL';

export const BOOKMARK_CATEGORY_UPDATE_REQUEST = 'BOOKMARK_CATEGORY_UPDATE_REQUEST';
export const BOOKMARK_CATEGORY_UPDATE_SUCCESS = 'BOOKMARK_CATEGORY_UPDATE_SUCCESS';
export const BOOKMARK_CATEGORY_UPDATE_FAIL    = 'BOOKMARK_CATEGORY_UPDATE_FAIL';

export const BOOKMARK_CATEGORY_DELETE_REQUEST = 'BOOKMARK_CATEGORY_DELETE_REQUEST';
export const BOOKMARK_CATEGORY_DELETE_SUCCESS = 'BOOKMARK_CATEGORY_DELETE_SUCCESS';
export const BOOKMARK_CATEGORY_DELETE_FAIL    = 'BOOKMARK_CATEGORY_DELETE_FAIL';

export const BOOKMARK_CATEGORY_STATUSES_FETCH_REQUEST = 'BOOKMARK_CATEGORY_STATUSES_FETCH_REQUEST';
export const BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS = 'BOOKMARK_CATEGORY_STATUSES_FETCH_SUCCESS';
export const BOOKMARK_CATEGORY_STATUSES_FETCH_FAIL    = 'BOOKMARK_CATEGORY_STATUSES_FETCH_FAIL';

export const BOOKMARK_CATEGORY_EDITOR_ADD_REQUEST = 'BOOKMARK_CATEGORY_EDITOR_ADD_REQUEST';
export const BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS = 'BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS';
export const BOOKMARK_CATEGORY_EDITOR_ADD_FAIL    = 'BOOKMARK_CATEGORY_EDITOR_ADD_FAIL';

export const BOOKMARK_CATEGORY_EDITOR_REMOVE_REQUEST = 'BOOKMARK_CATEGORY_EDITOR_REMOVE_REQUEST';
export const BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS = 'BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS';
export const BOOKMARK_CATEGORY_EDITOR_REMOVE_FAIL    = 'BOOKMARK_CATEGORY_EDITOR_REMOVE_FAIL';

export const BOOKMARK_CATEGORY_ADDER_RESET = 'BOOKMARK_CATEGORY_ADDER_RESET';
export const BOOKMARK_CATEGORY_ADDER_SETUP = 'BOOKMARK_CATEGORY_ADDER_SETUP';

export const BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_REQUEST = 'BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_REQUEST';
export const BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_SUCCESS = 'BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_SUCCESS';
export const BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_FAIL    = 'BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_FAIL';

export const BOOKMARK_CATEGORY_STATUSES_EXPAND_REQUEST = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_REQUEST';
export const BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_SUCCESS';
export const BOOKMARK_CATEGORY_STATUSES_EXPAND_FAIL    = 'BOOKMARK_CATEGORY_STATUSES_EXPAND_FAIL';

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

export const submitBookmarkCategoryEditor = shouldReset => (dispatch, getState) => {
  const bookmarkCategoryId = getState().getIn(['bookmarkCategoryEditor', 'bookmarkCategoryId']);
  const title  = getState().getIn(['bookmarkCategoryEditor', 'title']);

  if (bookmarkCategoryId === null) {
    dispatch(createBookmarkCategory(title, shouldReset));
  } else {
    dispatch(updateBookmarkCategory(bookmarkCategoryId, title, shouldReset));
  }
};

export const setupBookmarkCategoryEditor = bookmarkCategoryId => (dispatch, getState) => {
  dispatch({
    type: BOOKMARK_CATEGORY_EDITOR_SETUP,
    bookmarkCategory: getState().getIn(['bookmark_categories', bookmarkCategoryId]),
  });

  dispatch(fetchBookmarkCategoryStatuses(bookmarkCategoryId));
};

export const changeBookmarkCategoryEditorTitle = value => ({
  type: BOOKMARK_CATEGORY_EDITOR_TITLE_CHANGE,
  value,
});

export const createBookmarkCategory = (title, shouldReset) => (dispatch, getState) => {
  dispatch(createBookmarkCategoryRequest());

  api(getState).post('/api/v1/bookmark_categories', { title }).then(({ data }) => {
    dispatch(createBookmarkCategorySuccess(data));

    if (shouldReset) {
      dispatch(resetBookmarkCategoryEditor());
    }
  }).catch(err => dispatch(createBookmarkCategoryFail(err)));
};

export const createBookmarkCategoryRequest = () => ({
  type: BOOKMARK_CATEGORY_CREATE_REQUEST,
});

export const createBookmarkCategorySuccess = bookmarkCategory => ({
  type: BOOKMARK_CATEGORY_CREATE_SUCCESS,
  bookmarkCategory,
});

export const createBookmarkCategoryFail = error => ({
  type: BOOKMARK_CATEGORY_CREATE_FAIL,
  error,
});

export const updateBookmarkCategory = (id, title, shouldReset) => (dispatch, getState) => {
  dispatch(updateBookmarkCategoryRequest(id));

  api(getState).put(`/api/v1/bookmark_categories/${id}`, { title }).then(({ data }) => {
    dispatch(updateBookmarkCategorySuccess(data));

    if (shouldReset) {
      dispatch(resetBookmarkCategoryEditor());
    }
  }).catch(err => dispatch(updateBookmarkCategoryFail(id, err)));
};

export const updateBookmarkCategoryRequest = id => ({
  type: BOOKMARK_CATEGORY_UPDATE_REQUEST,
  id,
});

export const updateBookmarkCategorySuccess = bookmarkCategory => ({
  type: BOOKMARK_CATEGORY_UPDATE_SUCCESS,
  bookmarkCategory,
});

export const updateBookmarkCategoryFail = (id, error) => ({
  type: BOOKMARK_CATEGORY_UPDATE_FAIL,
  id,
  error,
});

export const resetBookmarkCategoryEditor = () => ({
  type: BOOKMARK_CATEGORY_EDITOR_RESET,
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

export const addToBookmarkCategory = (bookmarkCategoryId, statusId) => (dispatch, getState) => {
  dispatch(addToBookmarkCategoryRequest(bookmarkCategoryId, statusId));

  api(getState).post(`/api/v1/bookmark_categories/${bookmarkCategoryId}/statuses`, { status_ids: [statusId] })
    .then(() => dispatch(addToBookmarkCategorySuccess(bookmarkCategoryId, statusId)))
    .catch(err => dispatch(addToBookmarkCategoryFail(bookmarkCategoryId, statusId, err)));
};

export const addToBookmarkCategoryRequest = (bookmarkCategoryId, statusId) => ({
  type: BOOKMARK_CATEGORY_EDITOR_ADD_REQUEST,
  bookmarkCategoryId,
  statusId,
});

export const addToBookmarkCategorySuccess = (bookmarkCategoryId, statusId) => ({
  type: BOOKMARK_CATEGORY_EDITOR_ADD_SUCCESS,
  bookmarkCategoryId,
  statusId,
});

export const addToBookmarkCategoryFail = (bookmarkCategoryId, statusId, error) => ({
  type: BOOKMARK_CATEGORY_EDITOR_ADD_FAIL,
  bookmarkCategoryId,
  statusId,
  error,
});

export const removeFromBookmarkCategory = (bookmarkCategoryId, statusId) => (dispatch, getState) => {
  dispatch(removeFromBookmarkCategoryRequest(bookmarkCategoryId, statusId));

  api(getState).delete(`/api/v1/bookmark_categories/${bookmarkCategoryId}/statuses`, { params: { status_ids: [statusId] } })
    .then(() => dispatch(removeFromBookmarkCategorySuccess(bookmarkCategoryId, statusId)))
    .catch(err => dispatch(removeFromBookmarkCategoryFail(bookmarkCategoryId, statusId, err)));
};

export const removeFromBookmarkCategoryRequest = (bookmarkCategoryId, statusId) => ({
  type: BOOKMARK_CATEGORY_EDITOR_REMOVE_REQUEST,
  bookmarkCategoryId,
  statusId,
});

export const removeFromBookmarkCategorySuccess = (bookmarkCategoryId, statusId) => ({
  type: BOOKMARK_CATEGORY_EDITOR_REMOVE_SUCCESS,
  bookmarkCategoryId,
  statusId,
});

export const removeFromBookmarkCategoryFail = (bookmarkCategoryId, statusId, error) => ({
  type: BOOKMARK_CATEGORY_EDITOR_REMOVE_FAIL,
  bookmarkCategoryId,
  statusId,
  error,
});

export const resetBookmarkCategoryAdder = () => ({
  type: BOOKMARK_CATEGORY_ADDER_RESET,
});

export const setupBookmarkCategoryAdder = statusId => (dispatch, getState) => {
  dispatch({
    type: BOOKMARK_CATEGORY_ADDER_SETUP,
    status: getState().getIn(['statuses', statusId]),
  });
  dispatch(fetchBookmarkCategories());
  dispatch(fetchStatusBookmarkCategories(statusId));
};

export const fetchStatusBookmarkCategories = statusId => (dispatch, getState) => {
  dispatch(fetchStatusBookmarkCategoriesRequest(statusId));

  api(getState).get(`/api/v1/statuses/${statusId}/bookmark_categories`)
    .then(({ data }) => dispatch(fetchStatusBookmarkCategoriesSuccess(statusId, data)))
    .catch(err => dispatch(fetchStatusBookmarkCategoriesFail(statusId, err)));
};

export const fetchStatusBookmarkCategoriesRequest = id => ({
  type:BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_REQUEST,
  id,
});

export const fetchStatusBookmarkCategoriesSuccess = (id, bookmarkCategories) => ({
  type: BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_SUCCESS,
  id,
  bookmarkCategories,
});

export const fetchStatusBookmarkCategoriesFail = (id, err) => ({
  type: BOOKMARK_CATEGORY_ADDER_BOOKMARK_CATEGORIES_FETCH_FAIL,
  id,
  err,
});

export const addToBookmarkCategoryAdder = bookmarkCategoryId => (dispatch, getState) => {
  dispatch(addToBookmarkCategory(bookmarkCategoryId, getState().getIn(['bookmarkCategoryAdder', 'statusId'])));
};

export const removeFromBookmarkCategoryAdder = bookmarkCategoryId => (dispatch, getState) => {
  if (bookmarkCategoryNeeded) {
    const categories = getState().getIn(['bookmarkCategoryAdder', 'bookmarkCategories', 'items']);
    if (categories && categories.count() <= 1) {
      const status = makeGetStatus()(getState(), { id: getState().getIn(['bookmarkCategoryAdder', 'statusId']) });
      dispatch(unbookmark(status));
    } else {
      dispatch(removeFromBookmarkCategory(bookmarkCategoryId, getState().getIn(['bookmarkCategoryAdder', 'statusId'])));
    }
  } else {
    dispatch(removeFromBookmarkCategory(bookmarkCategoryId, getState().getIn(['bookmarkCategoryAdder', 'statusId'])));
  }
};

export function expandBookmarkCategoryStatuses(bookmarkCategoryId) {
  return (dispatch, getState) => {
    const url = getState().getIn(['bookmark_categories', bookmarkCategoryId, 'next'], null);

    if (url === null || getState().getIn(['bookmark_categories', bookmarkCategoryId, 'isLoading'])) {
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

