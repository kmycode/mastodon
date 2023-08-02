import { Map as ImmutableMap, fromJS } from 'immutable';

import {
  ANTENNAS_FETCH_SUCCESS,
} from '../actions/antennas';

const initialState = ImmutableMap();

const normalizeAntenna = (state, antenna) => state.set(antenna.id, fromJS(antenna));

const normalizeAntennas = (state, antennas) => {
  antennas.forEach(antenna => {
    state = normalizeAntenna(state, antenna);
  });

  return state;
};

export default function antennas(state = initialState, action) {
  switch(action.type) {
  case ANTENNAS_FETCH_SUCCESS:
    return normalizeAntennas(state, action.antennas);
  default:
    return state;
  }
}
