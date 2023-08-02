import api from '../api';

import { importFetchedAccounts } from './importer';

export const ANTENNAS_FETCH_REQUEST = 'ANTENNAS_FETCH_REQUEST';
export const ANTENNAS_FETCH_SUCCESS = 'ANTENNAS_FETCH_SUCCESS';
export const ANTENNAS_FETCH_FAIL    = 'ANTENNAS_FETCH_FAIL';

export const ANTENNA_ACCOUNTS_FETCH_REQUEST = 'ANTENNA_ACCOUNTS_FETCH_REQUEST';
export const ANTENNA_ACCOUNTS_FETCH_SUCCESS = 'ANTENNA_ACCOUNTS_FETCH_SUCCESS';
export const ANTENNA_ACCOUNTS_FETCH_FAIL    = 'ANTENNA_ACCOUNTS_FETCH_FAIL';

export const ANTENNA_EDITOR_ADD_ACCOUNT_REQUEST = 'ANTENNA_EDITOR_ADD_ACCOUNT_REQUEST';
export const ANTENNA_EDITOR_ADD_ACCOUNT_SUCCESS = 'ANTENNA_EDITOR_ADD_ACCOUNT_SUCCESS';
export const ANTENNA_EDITOR_ADD_ACCOUNT_FAIL    = 'ANTENNA_EDITOR_ADD_ACCOUNT_FAIL';

export const ANTENNA_EDITOR_REMOVE_ACCOUNT_REQUEST = 'ANTENNA_EDITOR_REMOVE_ACCOUNT_REQUEST';
export const ANTENNA_EDITOR_REMOVE_ACCOUNT_SUCCESS = 'ANTENNA_EDITOR_REMOVE_ACCOUNT_SUCCESS';
export const ANTENNA_EDITOR_REMOVE_ACCOUNT_FAIL    = 'ANTENNA_EDITOR_REMOVE_ACCOUNT_FAIL';

export const ANTENNA_ADDER_ANTENNAS_FETCH_REQUEST = 'ANTENNA_ADDER_ANTENNAS_FETCH_REQUEST';
export const ANTENNA_ADDER_ANTENNAS_FETCH_SUCCESS = 'ANTENNA_ADDER_ANTENNAS_FETCH_SUCCESS';
export const ANTENNA_ADDER_ANTENNAS_FETCH_FAIL    = 'ANTENNA_ADDER_ANTENNAS_FETCH_FAIL';

export const ANTENNA_ADDER_RESET = 'ANTENNA_ADDER_RESET';
export const ANTENNA_ADDER_SETUP = 'ANTENNA_ADDER_SETUP';

export const fetchAntennas = () => (dispatch, getState) => {
  dispatch(fetchAntennasRequest());

  api(getState).get('/api/v1/antennas')
    .then(({ data }) => dispatch(fetchAntennasSuccess(data)))
    .catch(err => dispatch(fetchAntennasFail(err)));
};

export const fetchAntennasRequest = () => ({
  type: ANTENNAS_FETCH_REQUEST,
});

export const fetchAntennasSuccess = antennas => ({
  type: ANTENNAS_FETCH_SUCCESS,
  antennas,
});

export const fetchAntennasFail = error => ({
  type: ANTENNAS_FETCH_FAIL,
  error,
});

export const fetchAntennaAccounts = antennaId => (dispatch, getState) => {
  dispatch(fetchAntennaAccountsRequest(antennaId));

  api(getState).get(`/api/v1/antennas/${antennaId}/accounts`, { params: { limit: 0 } }).then(({ data }) => {
    dispatch(importFetchedAccounts(data));
    dispatch(fetchAntennaAccountsSuccess(antennaId, data));
  }).catch(err => dispatch(fetchAntennaAccountsFail(antennaId, err)));
};

export const fetchAntennaAccountsRequest = id => ({
  type: ANTENNA_ACCOUNTS_FETCH_REQUEST,
  id,
});

export const fetchAntennaAccountsSuccess = (id, accounts, next) => ({
  type: ANTENNA_ACCOUNTS_FETCH_SUCCESS,
  id,
  accounts,
  next,
});

export const fetchAntennaAccountsFail = (id, error) => ({
  type: ANTENNA_ACCOUNTS_FETCH_FAIL,
  id,
  error,
});

export const addAccountToAntenna = (antennaId, accountId) => (dispatch, getState) => {
  dispatch(addAccountToAntennaRequest(antennaId, accountId));

  api(getState).post(`/api/v1/antennas/${antennaId}/accounts`, { account_ids: [accountId] })
    .then(() => dispatch(addAccountToAntennaSuccess(antennaId, accountId)))
    .catch(err => dispatch(addAccountToAntennaFail(antennaId, accountId, err)));
};

export const addAccountToAntennaRequest = (antennaId, accountId) => ({
  type: ANTENNA_EDITOR_ADD_ACCOUNT_REQUEST,
  antennaId,
  accountId,
});

export const addAccountToAntennaSuccess = (antennaId, accountId) => ({
  type: ANTENNA_EDITOR_ADD_ACCOUNT_SUCCESS,
  antennaId,
  accountId,
});

export const addAccountToAntennaFail = (antennaId, accountId, error) => ({
  type: ANTENNA_EDITOR_ADD_ACCOUNT_FAIL,
  antennaId,
  accountId,
  error,
});

export const removeAccountFromAntennaEditor = accountId => (dispatch, getState) => {
  dispatch(removeAccountFromAntenna(getState().getIn(['antennaEditor', 'antennaId']), accountId));
};

export const removeAccountFromAntenna = (antennaId, accountId) => (dispatch, getState) => {
  dispatch(removeAccountFromAntennaRequest(antennaId, accountId));

  api(getState).delete(`/api/v1/antennas/${antennaId}/accounts`, { params: { account_ids: [accountId] } })
    .then(() => dispatch(removeAccountFromAntennaSuccess(antennaId, accountId)))
    .catch(err => dispatch(removeAccountFromAntennaFail(antennaId, accountId, err)));
};

export const removeAccountFromAntennaRequest = (antennaId, accountId) => ({
  type: ANTENNA_EDITOR_REMOVE_ACCOUNT_REQUEST,
  antennaId,
  accountId,
});

export const removeAccountFromAntennaSuccess = (antennaId, accountId) => ({
  type: ANTENNA_EDITOR_REMOVE_ACCOUNT_SUCCESS,
  antennaId,
  accountId,
});

export const removeAccountFromAntennaFail = (antennaId, accountId, error) => ({
  type: ANTENNA_EDITOR_REMOVE_ACCOUNT_FAIL,
  antennaId,
  accountId,
  error,
});

export const addToAntennaAdder = antennaId => (dispatch, getState) => {
  dispatch(addAccountToAntenna(antennaId, getState().getIn(['antennaAdder', 'accountId'])));
};

export const removeFromAntennaAdder = antennaId => (dispatch, getState) => {
  dispatch(removeAccountFromAntenna(antennaId, getState().getIn(['antennaAdder', 'accountId'])));
};

export const fetchAccountAntennas = accountId => (dispatch, getState) => {
  dispatch(fetchAccountAntennasRequest(accountId));

  api(getState).get(`/api/v1/accounts/${accountId}/antennas`)
    .then(({ data }) => dispatch(fetchAccountAntennasSuccess(accountId, data)))
    .catch(err => dispatch(fetchAccountAntennasFail(accountId, err)));
};

export const fetchAccountAntennasRequest = id => ({
  type: ANTENNA_ADDER_ANTENNAS_FETCH_REQUEST,
  id,
});

export const fetchAccountAntennasSuccess = (id, antennas) => ({
  type: ANTENNA_ADDER_ANTENNAS_FETCH_SUCCESS,
  id,
  antennas,
});

export const fetchAccountAntennasFail = (id, err) => ({
  type: ANTENNA_ADDER_ANTENNAS_FETCH_FAIL,
  id,
  err,
});

export const resetAntennaAdder = () => ({
  type: ANTENNA_ADDER_RESET,
});

export const setupAntennaAdder = accountId => (dispatch, getState) => {
  dispatch({
    type: ANTENNA_ADDER_SETUP,
    account: getState().getIn(['accounts', accountId]),
  });
  dispatch(fetchAntennas());
  dispatch(fetchAccountAntennas(accountId));
};

