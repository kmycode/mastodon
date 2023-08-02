import { Map as ImmutableMap, List as ImmutableList } from 'immutable';

import {
  ANTENNA_ADDER_RESET,
  ANTENNA_ADDER_SETUP,
  ANTENNA_ADDER_ANTENNAS_FETCH_REQUEST,
  ANTENNA_ADDER_ANTENNAS_FETCH_SUCCESS,
  ANTENNA_ADDER_ANTENNAS_FETCH_FAIL,
  ANTENNA_EDITOR_ADD_ACCOUNT_SUCCESS,
  ANTENNA_EDITOR_REMOVE_ACCOUNT_SUCCESS,
} from '../actions/antennas';

const initialState = ImmutableMap({
  accountId: null,

  antennas: ImmutableMap({
    items: ImmutableList(),
    loaded: false,
    isLoading: false,
  }),
});

export default function antennaAdderReducer(state = initialState, action) {
  switch(action.type) {
  case ANTENNA_ADDER_RESET:
    return initialState;
  case ANTENNA_ADDER_SETUP:
    return state.withMutations(map => {
      map.set('accountId', action.account.get('id'));
    });
  case ANTENNA_ADDER_ANTENNAS_FETCH_REQUEST:
    return state.setIn(['antennas', 'isLoading'], true);
  case ANTENNA_ADDER_ANTENNAS_FETCH_FAIL:
    return state.setIn(['antennas', 'isLoading'], false);
  case ANTENNA_ADDER_ANTENNAS_FETCH_SUCCESS:
    return state.update('antennas', antennas => antennas.withMutations(map => {
      map.set('isLoading', false);
      map.set('loaded', true);
      map.set('items', ImmutableList(action.antennas.map(item => item.id)));
    }));
  case ANTENNA_EDITOR_ADD_ACCOUNT_SUCCESS:
    return state.updateIn(['antennas', 'items'], antenna => antenna.unshift(action.antennaId));
  case ANTENNA_EDITOR_REMOVE_ACCOUNT_SUCCESS:
    return state.updateIn(['antennas', 'items'], antenna => antenna.filterNot(item => item === action.antennaId));
  default:
    return state;
  }
}
