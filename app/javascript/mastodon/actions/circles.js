import api, { getLinks } from '../api';

import { importFetchedStatuses } from './importer';

export const CIRCLE_FETCH_REQUEST = 'CIRCLE_FETCH_REQUEST';
export const CIRCLE_FETCH_SUCCESS = 'CIRCLE_FETCH_SUCCESS';
export const CIRCLE_FETCH_FAIL    = 'CIRCLE_FETCH_FAIL';

export const CIRCLES_FETCH_REQUEST = 'CIRCLES_FETCH_REQUEST';
export const CIRCLES_FETCH_SUCCESS = 'CIRCLES_FETCH_SUCCESS';
export const CIRCLES_FETCH_FAIL    = 'CIRCLES_FETCH_FAIL';

export const CIRCLE_CREATE_REQUEST = 'CIRCLE_CREATE_REQUEST';
export const CIRCLE_CREATE_SUCCESS = 'CIRCLE_CREATE_SUCCESS';
export const CIRCLE_CREATE_FAIL    = 'CIRCLE_CREATE_FAIL';

export const CIRCLE_UPDATE_REQUEST = 'CIRCLE_UPDATE_REQUEST';
export const CIRCLE_UPDATE_SUCCESS = 'CIRCLE_UPDATE_SUCCESS';
export const CIRCLE_UPDATE_FAIL    = 'CIRCLE_UPDATE_FAIL';

export const CIRCLE_DELETE_REQUEST = 'CIRCLE_DELETE_REQUEST';
export const CIRCLE_DELETE_SUCCESS = 'CIRCLE_DELETE_SUCCESS';
export const CIRCLE_DELETE_FAIL    = 'CIRCLE_DELETE_FAIL';

export const CIRCLE_STATUSES_FETCH_REQUEST = 'CIRCLE_STATUSES_FETCH_REQUEST';
export const CIRCLE_STATUSES_FETCH_SUCCESS = 'CIRCLE_STATUSES_FETCH_SUCCESS';
export const CIRCLE_STATUSES_FETCH_FAIL    = 'CIRCLE_STATUSES_FETCH_FAIL';

export const CIRCLE_STATUSES_EXPAND_REQUEST = 'CIRCLE_STATUSES_EXPAND_REQUEST';
export const CIRCLE_STATUSES_EXPAND_SUCCESS = 'CIRCLE_STATUSES_EXPAND_SUCCESS';
export const CIRCLE_STATUSES_EXPAND_FAIL    = 'CIRCLE_STATUSES_EXPAND_FAIL';

export const fetchCircle = id => (dispatch, getState) => {
  if (getState().getIn(['circles', id])) {
    return;
  }

  dispatch(fetchCircleRequest(id));

  api(getState).get(`/api/v1/circles/${id}`)
    .then(({ data }) => dispatch(fetchCircleSuccess(data)))
    .catch(err => dispatch(fetchCircleFail(id, err)));
};

export const fetchCircleRequest = id => ({
  type: CIRCLE_FETCH_REQUEST,
  id,
});

export const fetchCircleSuccess = circle => ({
  type: CIRCLE_FETCH_SUCCESS,
  circle,
});

export const fetchCircleFail = (id, error) => ({
  type: CIRCLE_FETCH_FAIL,
  id,
  error,
});

export const fetchCircles = () => (dispatch, getState) => {
  dispatch(fetchCirclesRequest());

  api(getState).get('/api/v1/circles')
    .then(({ data }) => dispatch(fetchCirclesSuccess(data)))
    .catch(err => dispatch(fetchCirclesFail(err)));
};

export const fetchCirclesRequest = () => ({
  type: CIRCLES_FETCH_REQUEST,
});

export const fetchCirclesSuccess = circles => ({
  type: CIRCLES_FETCH_SUCCESS,
  circles,
});

export const fetchCirclesFail = error => ({
  type: CIRCLES_FETCH_FAIL,
  error,
});

export const deleteCircle = id => (dispatch, getState) => {
  dispatch(deleteCircleRequest(id));

  api(getState).delete(`/api/v1/circles/${id}`)
    .then(() => dispatch(deleteCircleSuccess(id)))
    .catch(err => dispatch(deleteCircleFail(id, err)));
};

export const deleteCircleRequest = id => ({
  type: CIRCLE_DELETE_REQUEST,
  id,
});

export const deleteCircleSuccess = id => ({
  type: CIRCLE_DELETE_SUCCESS,
  id,
});

export const deleteCircleFail = (id, error) => ({
  type: CIRCLE_DELETE_FAIL,
  id,
  error,
});

export function fetchCircleStatuses(circleId) {
  return (dispatch, getState) => {
    if (getState().getIn(['circles', circleId, 'isLoading'])) {
      return;
    }
    const items = getState().getIn(['circles', circleId, 'items']);
    if (items && items.size > 0) {
      return;
    }

    dispatch(fetchCircleStatusesRequest(circleId));

    api(getState).get(`/api/v1/circles/${circleId}/statuses`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedStatuses(response.data));
      dispatch(fetchCircleStatusesSuccess(circleId, response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(fetchCircleStatusesFail(circleId, error));
    });
  };
}

export function fetchCircleStatusesRequest(id) {
  return {
    type: CIRCLE_STATUSES_FETCH_REQUEST,
    id,
  };
}

export function fetchCircleStatusesSuccess(id, statuses, next) {
  return {
    type: CIRCLE_STATUSES_FETCH_SUCCESS,
    id,
    statuses,
    next,
  };
}

export function fetchCircleStatusesFail(id, error) {
  return {
    type: CIRCLE_STATUSES_FETCH_FAIL,
    id,
    error,
  };
}

export function expandCircleStatuses(circleId) {
  return (dispatch, getState) => {
    const url = getState().getIn(['status_lists', 'circle_statuses', circleId, 'next'], null);

    if (url === null || getState().getIn(['status_lists', 'circle_statuses', circleId, 'isLoading'])) {
      return;
    }

    dispatch(expandCircleStatusesRequest(circleId));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedStatuses(response.data));
      dispatch(expandCircleStatusesSuccess(circleId, response.data, next ? next.uri : null));
    }).catch(error => {
      dispatch(expandCircleStatusesFail(circleId, error));
    });
  };
}

export function expandCircleStatusesRequest(id) {
  return {
    type: CIRCLE_STATUSES_EXPAND_REQUEST,
    id,
  };
}

export function expandCircleStatusesSuccess(id, statuses, next) {
  return {
    type: CIRCLE_STATUSES_EXPAND_SUCCESS,
    id,
    statuses,
    next,
  };
}

export function expandCircleStatusesFail(id, error) {
  return {
    type: CIRCLE_STATUSES_EXPAND_FAIL,
    id,
    error,
  };
}

