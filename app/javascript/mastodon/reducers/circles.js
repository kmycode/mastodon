import { List as ImmutableList, OrderedSet as ImmutableOrderedSet, fromJS } from 'immutable';

import {
  CIRCLE_FETCH_SUCCESS,
  CIRCLE_FETCH_FAIL,
  CIRCLES_FETCH_SUCCESS,
  CIRCLE_CREATE_SUCCESS,
  CIRCLE_UPDATE_SUCCESS,
  CIRCLE_DELETE_SUCCESS,
  CIRCLE_STATUSES_FETCH_REQUEST,
  CIRCLE_STATUSES_FETCH_SUCCESS,
  CIRCLE_STATUSES_FETCH_FAIL,
  CIRCLE_STATUSES_EXPAND_REQUEST,
  CIRCLE_STATUSES_EXPAND_SUCCESS,
  CIRCLE_STATUSES_EXPAND_FAIL,
} from '../actions/circles';

const initialState = ImmutableList();

const normalizeList = (state, circle) => state.set(circle.id, fromJS(circle));

const normalizeLists = (state, circles) => {
  circles.forEach(circle => {
    state = normalizeList(state, circle);
  });

  return state;
};

const normalizeCircleStatuses = (state, circleId, statuses, next) => {
  return state.updateIn([circleId, 'statuses'], listMap => listMap.withMutations(map => {
    map.set('next', next);
    map.set('loaded', true);
    map.set('isLoading', false);
    map.set('items', ImmutableOrderedSet(statuses.map(item => item.id)));
  }));
};

const appendToCircleStatuses = (state, circleId, statuses, next) => {
  return appendToCircleStatusesById(state, circleId, statuses.map(item => item.id), next);
};

const appendToCircleStatusesById = (state, circleId, statuses, next) => {
  return state.updateIn([circleId, 'statuses'], listMap => listMap.withMutations(map => {
    if (typeof next !== 'undefined') {
      map.set('next', next);
    }
    map.set('isLoading', false);
    if (map.get('items')) {
      map.set('items', map.get('items').union(statuses));
    }
  }));
};

export default function circles(state = initialState, action) {
  switch(action.type) {
  case CIRCLE_FETCH_SUCCESS:
  case CIRCLE_CREATE_SUCCESS:
  case CIRCLE_UPDATE_SUCCESS:
    return normalizeList(state, action.circle);
  case CIRCLES_FETCH_SUCCESS:
    return normalizeLists(state, action.circles);
  case CIRCLE_DELETE_SUCCESS:
  case CIRCLE_FETCH_FAIL:
    return state.set(action.id, false);
  case CIRCLE_STATUSES_FETCH_REQUEST:
  case CIRCLE_STATUSES_EXPAND_REQUEST:
    return state.setIn([action.id, 'statuses', 'isLoading'], true);
  case CIRCLE_STATUSES_FETCH_FAIL:
  case CIRCLE_STATUSES_EXPAND_FAIL:
    return state.setIn([action.id, 'statuses', 'isLoading'], false);
  case CIRCLE_STATUSES_FETCH_SUCCESS:
    return normalizeCircleStatuses(state, action.id, action.statuses, action.next);
  case CIRCLE_STATUSES_EXPAND_SUCCESS:
    return appendToCircleStatuses(state, action.id, action.statuses, action.next);
  default:
    return state;
  }
}
