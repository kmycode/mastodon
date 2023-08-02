import { Map as ImmutableMap, List as ImmutableList } from 'immutable';

import {
  ANTENNA_ACCOUNTS_FETCH_REQUEST,
  ANTENNA_ACCOUNTS_FETCH_SUCCESS,
  ANTENNA_ACCOUNTS_FETCH_FAIL,
} from '../actions/antennas';

const initialState = ImmutableMap({
  antennaId: null,
  isSubmitting: false,
  isChanged: false,
  title: '',

  accounts: ImmutableMap({
    items: ImmutableList(),
    loaded: false,
    isLoading: false,
  }),
});

export default function antennaEditorReducer(state = initialState, action) {
  switch(action.type) {
  case ANTENNA_ACCOUNTS_FETCH_REQUEST:
    return state.setIn(['accounts', 'isLoading'], true);
  case ANTENNA_ACCOUNTS_FETCH_FAIL:
    return state.setIn(['accounts', 'isLoading'], false);
  case ANTENNA_ACCOUNTS_FETCH_SUCCESS:
    return state.update('accounts', accounts => accounts.withMutations(map => {
      map.set('isLoading', false);
      map.set('loaded', true);
      map.set('items', ImmutableList(action.accounts.map(item => item.id)));
    }));
  default:
    return state;
  }
}
