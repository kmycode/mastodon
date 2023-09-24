import { List as ImmutableList, Map as ImmutableMap, OrderedSet as ImmutableOrderedSet, fromJS } from 'immutable';

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
import {
  COMPOSE_WITH_CIRCLE_SUCCESS,
} from '../actions/compose';

const initialState = ImmutableList();

const initialStatusesState = ImmutableMap({
  items: ImmutableList(),
  isLoading: false,
  next: null,
});

const normalizeCircle = (state, circle) => {
  const old = state.get(circle.id);
  if (old === false) {
    return state;
  }

  let s = state.set(circle.id, fromJS(circle));
  if (old) {
    s = s.setIn([circle.id, 'statuses'], old.get('statuses'));
  } else {
    s = s.setIn([circle.id, 'statuses'], initialStatusesState);
  }
  return s;
};

const normalizeCircles = (state, circles) => {
  circles.forEach(circle => {
    state = normalizeCircle(state, circle);
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

const prependToCircleStatusById = (state, circleId, statusId) => {
  if (!state.get(circleId)) return state;

  return state.updateIn([circleId], circle => circle.withMutations(map => {
    if (map.getIn(['statuses', 'items'])) {
      map.updateIn(['statuses', 'items'], list => ImmutableOrderedSet([statusId]).union(list));
    }
  }));
}

export default function circles(state = initialState, action) {
  switch(action.type) {
  case CIRCLE_FETCH_SUCCESS:
  case CIRCLE_CREATE_SUCCESS:
  case CIRCLE_UPDATE_SUCCESS:
    return normalizeCircle(state, action.circle);
  case CIRCLES_FETCH_SUCCESS:
    return normalizeCircles(state, action.circles);
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
  case COMPOSE_WITH_CIRCLE_SUCCESS:
    return prependToCircleStatusById(state, action.circleId, action.status.id);
  default:
    return state;
  }
}
