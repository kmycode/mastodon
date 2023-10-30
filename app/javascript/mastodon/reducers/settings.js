import { Map as ImmutableMap, fromJS } from 'immutable';

import { ANTENNA_DELETE_SUCCESS, ANTENNA_FETCH_FAIL } from 'mastodon/actions/antennas';
import { BOOKMARK_CATEGORY_DELETE_SUCCESS, BOOKMARK_CATEGORY_FETCH_FAIL } from 'mastodon/actions/bookmark_categories';
import { CIRCLE_DELETE_SUCCESS, CIRCLE_FETCH_FAIL } from 'mastodon/actions/circles';

import { COLUMN_ADD, COLUMN_REMOVE, COLUMN_MOVE, COLUMN_PARAMS_CHANGE } from '../actions/columns';
import { EMOJI_USE } from '../actions/emojis';
import { LANGUAGE_USE } from '../actions/languages';
import { LIST_DELETE_SUCCESS, LIST_FETCH_FAIL } from '../actions/lists';
import { NOTIFICATIONS_FILTER_SET } from '../actions/notifications';
import { SETTING_CHANGE, SETTING_SAVE } from '../actions/settings';
import { STORE_HYDRATE } from '../actions/store';
import { uuid } from '../uuid';

const initialState = ImmutableMap({
  saved: true,

  skinTone: 1,

  trends: ImmutableMap({
    show: true,
  }),

  home: ImmutableMap({
    shows: ImmutableMap({
      reblog: true,
      reply: true,
    }),

    regex: ImmutableMap({
      body: '',
    }),
  }),

  notifications: ImmutableMap({
    alerts: ImmutableMap({
      follow: false,
      follow_request: false,
      favourite: false,
      reblog: false,
      mention: false,
      poll: false,
      status: false,
      list_status: false,
      update: false,
      emoji_reaction: false,
      status_reference: false,
      'admin.sign_up': false,
      'admin.report': false,
    }),

    quickFilter: ImmutableMap({
      active: 'all',
      show: true,
      advanced: false,
    }),

    dismissPermissionBanner: false,
    showUnread: true,

    shows: ImmutableMap({
      follow: true,
      follow_request: false,
      favourite: true,
      reblog: true,
      mention: true,
      poll: true,
      status: true,
      list_status: true,
      update: true,
      emoji_reaction: true,
      status_reference: true,
      'admin.sign_up': true,
      'admin.report': true,
    }),

    sounds: ImmutableMap({
      follow: true,
      follow_request: false,
      favourite: true,
      reblog: true,
      mention: true,
      poll: true,
      status: true,
      list_status: true,
      update: true,
      emoji_reaction: true,
      status_reference: true,
      'admin.sign_up': true,
      'admin.report': true,
    }),
  }),

  firehose: ImmutableMap({
    onlyMedia: false,
  }),

  community: ImmutableMap({
    regex: ImmutableMap({
      body: '',
    }),
  }),

  public: ImmutableMap({
    regex: ImmutableMap({
      body: '',
    }),
  }),

  direct: ImmutableMap({
    regex: ImmutableMap({
      body: '',
    }),
  }),
});

const defaultColumns = fromJS([
  { id: 'COMPOSE', uuid: uuid(), params: {} },
  { id: 'HOME', uuid: uuid(), params: {} },
  { id: 'NOTIFICATIONS', uuid: uuid(), params: {} },
]);

const hydrate = (state, settings) => state.mergeDeep(settings).update('columns', (val = defaultColumns) => val);

const moveColumn = (state, uuid, direction) => {
  const columns  = state.get('columns');
  const index    = columns.findIndex(item => item.get('uuid') === uuid);
  const newIndex = index + direction;

  let newColumns;

  newColumns = columns.splice(index, 1);
  newColumns = newColumns.splice(newIndex, 0, columns.get(index));

  return state
    .set('columns', newColumns)
    .set('saved', false);
};

const changeColumnParams = (state, uuid, path, value) => {
  const columns = state.get('columns');
  const index   = columns.findIndex(item => item.get('uuid') === uuid);

  const newColumns = columns.update(index, column => column.updateIn(['params', ...path], () => value));

  return state
    .set('columns', newColumns)
    .set('saved', false);
};

const updateFrequentEmojis = (state, emoji) => state.update('frequentlyUsedEmojis', ImmutableMap(), map => map.update(emoji.id, 0, count => count + 1)).set('saved', false);

const updateFrequentLanguages = (state, language) => state.update('frequentlyUsedLanguages', ImmutableMap(), map => map.update(language, 0, count => count + 1)).set('saved', false);

const filterDeadListColumns = (state, listId) => state.update('columns', columns => columns.filterNot(column => column.get('id') === 'LIST' && column.get('params').get('id') === listId));

const filterDeadBookmarkCategoryColumns = (state, bookmarkCategoryId) => state.update('columns', columns => columns.filterNot(column => column.get('id') === 'BOOKMARKS_EX' && column.get('params').get('id') === bookmarkCategoryId));

const filterDeadAntennaColumns = (state, antennaId) => state.update('columns', columns => columns.filterNot(column => (column.get('id') === 'ANTENNA' || column.get('id') === 'ANTENNA_TIMELINE') && column.get('params').get('id') === antennaId));

const filterDeadCircleColumns = (state, circleId) => state.update('columns', columns => columns.filterNot(column => column.get('id') === 'CIRCLE' && column.get('params').get('id') === circleId));

export default function settings(state = initialState, action) {
  switch(action.type) {
  case STORE_HYDRATE:
    return hydrate(state, action.state.get('settings'));
  case NOTIFICATIONS_FILTER_SET:
  case SETTING_CHANGE:
    return state
      .setIn(action.path, action.value)
      .set('saved', false);
  case COLUMN_ADD:
    return state
      .update('columns', list => list.push(fromJS({ id: action.id, uuid: uuid(), params: action.params })))
      .set('saved', false);
  case COLUMN_REMOVE:
    return state
      .update('columns', list => list.filterNot(item => item.get('uuid') === action.uuid))
      .set('saved', false);
  case COLUMN_MOVE:
    return moveColumn(state, action.uuid, action.direction);
  case COLUMN_PARAMS_CHANGE:
    return changeColumnParams(state, action.uuid, action.path, action.value);
  case EMOJI_USE:
    return updateFrequentEmojis(state, action.emoji);
  case LANGUAGE_USE:
    return updateFrequentLanguages(state, action.language);
  case SETTING_SAVE:
    return state.set('saved', true);
  case LIST_FETCH_FAIL:
    return action.error.response.status === 404 ? filterDeadListColumns(state, action.id) : state;
  case LIST_DELETE_SUCCESS:
    return filterDeadListColumns(state, action.id);
  case BOOKMARK_CATEGORY_FETCH_FAIL:
    return action.error.response.status === 404 ? filterDeadBookmarkCategoryColumns(state, action.id) : state;
  case BOOKMARK_CATEGORY_DELETE_SUCCESS:
    return filterDeadBookmarkCategoryColumns(state, action.id);
  case ANTENNA_FETCH_FAIL:
    return action.error.response.status === 404 ? filterDeadAntennaColumns(state, action.id) : state;
  case ANTENNA_DELETE_SUCCESS:
    return filterDeadAntennaColumns(state, action.id);
  case CIRCLE_FETCH_FAIL:
    return action.error.response.status === 404 ? filterDeadCircleColumns(state, action.id) : state;
  case CIRCLE_DELETE_SUCCESS:
    return filterDeadCircleColumns(state, action.id);
  default:
    return state;
  }
}
