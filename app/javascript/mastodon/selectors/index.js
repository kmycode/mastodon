import { createSelector } from '@reduxjs/toolkit';
import { List as ImmutableList, Map as ImmutableMap } from 'immutable';

import { me, isHideItem } from '../initial_state';

import { getFilters } from './filters';

export { makeGetAccount } from "./accounts";

export const makeGetStatus = () => {
  return createSelector(
    [
      (state, { id }) => state.getIn(['statuses', id]),
      (state, { id }) => state.getIn(['statuses', state.getIn(['statuses', id, 'reblog'])]),
      (state, { id }) => state.getIn(['statuses', state.getIn(['statuses', id, 'quote_id'])]),
      (state, { id }) => state.getIn(['statuses', state.getIn(['statuses', state.getIn(['statuses', id, 'reblog']), 'quote_id'])]),
      (state, { id }) => state.getIn(['accounts', state.getIn(['statuses', id, 'account'])]),
      (state, { id }) => state.getIn(['accounts', state.getIn(['statuses', state.getIn(['statuses', id, 'reblog']), 'account'])]),
      getFilters,
    ],

    (statusBase, statusReblog, statusQuote, statusReblogQuote, accountBase, accountReblog, filters) => {
      if (!statusBase || statusBase.get('isLoading')) {
        return null;
      }

      if (statusReblog) {
        statusReblog = statusReblog.set('account', accountReblog);
        statusQuote = statusReblogQuote;
      } else {
        statusReblog = null;
      }

      if (isHideItem('blocking_quote') && (statusReblog || statusBase).getIn(['quote', 'quote_muted'])) {
        return null;
      }

      let filtered = false;
      if ((accountReblog || accountBase).get('id') !== me && filters) {
        let filterResults = statusReblog?.get('filtered') || statusBase.get('filtered') || ImmutableList();
        const quoteFilterResults = statusQuote?.get('filtered');
        if (quoteFilterResults) {
          const filterWithQuote = quoteFilterResults.some((result) => filters.getIn([result.get('filter'), 'with_quote']));
          if (filterWithQuote) {
            filterResults = filterResults.concat(quoteFilterResults);
          }
        }

        if (filterResults.some((result) => filters.getIn([result.get('filter'), 'filter_action']) === 'hide')) {
          return null;
        }
        filterResults = filterResults.filter(result => filters.has(result.get('filter')));
        if (!filterResults.isEmpty()) {
          filtered = filterResults.map(result => filters.getIn([result.get('filter'), 'title']));
        }
      }

      return statusBase.withMutations(map => {
        map.set('reblog', statusReblog);
        map.set('quote', statusQuote);
        map.set('account', accountBase);
        map.set('matched_filters', filtered);
      });
    },
  );
};

export const makeGetPictureInPicture = () => {
  return createSelector([
    (state, { id }) => state.picture_in_picture.statusId === id,
    (state) => state.getIn(['meta', 'layout']) !== 'mobile',
  ], (inUse, available) => ImmutableMap({
    inUse: inUse && available,
    available,
  }));
};

const ALERT_DEFAULTS = {
  dismissAfter: 5000,
  style: false,
};

const formatIfNeeded = (intl, message, values) => {
  if (typeof message === 'object') {
    return intl.formatMessage(message, values);
  }

  return message;
};

export const getAlerts = createSelector([state => state.get('alerts'), (_, { intl }) => intl], (alerts, intl) =>
  alerts.map(item => ({
    ...ALERT_DEFAULTS,
    ...item,
    action: formatIfNeeded(intl, item.action, item.values),
    title: formatIfNeeded(intl, item.title, item.values),
    message: formatIfNeeded(intl, item.message, item.values),
  })).toArray());

export const makeGetNotification = () => createSelector([
  (_, base)             => base,
  (state, _, accountId) => state.getIn(['accounts', accountId]),
], (base, account) => base.set('account', account));

export const makeGetReport = () => createSelector([
  (_, base) => base,
  (state, _, targetAccountId) => state.getIn(['accounts', targetAccountId]),
], (base, targetAccount) => base.set('target_account', targetAccount));

export const getAccountGallery = createSelector([
  (state, id) => state.getIn(['timelines', `account:${id}:media`, 'items'], ImmutableList()),
  state       => state.get('statuses'),
  (state, id) => state.getIn(['accounts', id]),
], (statusIds, statuses, account) => {
  let medias = ImmutableList();

  statusIds.forEach(statusId => {
    const status = statuses.get(statusId).set('account', account);
    medias = medias.concat(status.get('media_attachments').map(media => media.set('status', status)));
  });

  return medias;
});

export const getAccountHidden = createSelector([
  (state, id) => state.getIn(['accounts', id, 'hidden']),
  (state, id) => state.getIn(['relationships', id, 'following']) || state.getIn(['relationships', id, 'requested']),
  (state, id) => id === me,
], (hidden, followingOrRequested, isSelf) => {
  return hidden && !(isSelf || followingOrRequested);
});

export const getStatusList = createSelector([
  (state, type) => state.getIn(['status_lists', type, 'items']),
], (items) => items.toList());

export const getBookmarkCategoryStatusList = createSelector([
  (state, bookmarkCategoryId) => state.getIn(['status_lists', 'bookmark_category_statuses', bookmarkCategoryId, 'items']),
], (items) => items ? items.toList() : ImmutableList());

export const getCircleStatusList = createSelector([
  (state, circleId) => state.getIn(['status_lists', 'circle_statuses', circleId, `items`]),
], (items) => items ? items.toList() : ImmutableList());
