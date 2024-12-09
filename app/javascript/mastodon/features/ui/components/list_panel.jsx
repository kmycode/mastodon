import { useEffect } from 'react';

import { createSelector } from '@reduxjs/toolkit';
import { useDispatch, useSelector } from 'react-redux';

import ListAltActiveIcon from '@/material-icons/400-24px/list_alt-fill.svg?react';
import ListAltIcon from '@/material-icons/400-24px/list_alt.svg?react';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { fetchAntennas } from 'mastodon/actions/antennas';
import { fetchLists } from 'mastodon/actions/lists';

import ColumnLink from './column_link';

const getOrderedLists = createSelector([state => state.get('lists')], lists => {
  if (!lists) {
    return lists;
  }

  return lists.toList().filter(item => !!item && item.get('favourite')).sort((a, b) => a.get('title').localeCompare(b.get('title'))).take(8);
});

const getOrderedAntennas = createSelector([state => state.get('antennas')], antennas => {
  if (!antennas) {
    return antennas;
  }

  return antennas.toList().filter(item => !!item && item.get('favourite') && item.get('title') !== undefined).sort((a, b) => a.get('title').localeCompare(b.get('title'))).take(8);
});

export const ListPanel = () => {
  const dispatch = useDispatch();
  const lists = useSelector(state => getOrderedLists(state));
  const antennas = useSelector(state => getOrderedAntennas(state));

  useEffect(() => {
    dispatch(fetchLists());
    dispatch(fetchAntennas());
  }, [dispatch]);

  const size = (lists ? lists.size : 0) + (antennas ? antennas.size : 0);
  if (size === 0) {
    return null;
  }

  return (
    <div className='list-panel'>
      <hr />

      {lists && lists.map(list => (
        <ColumnLink icon='list-ul' key={list.get('id')} iconComponent={ListAltIcon} activeIconComponent={ListAltActiveIcon} text={list.get('title')} to={`/lists/${list.get('id')}`} transparent />
      ))}
      {antennas && antennas.map(antenna => (
        <ColumnLink icon='wifi' key={antenna.get('id')} iconComponent={AntennaIcon} activeIconComponent={AntennaIcon} text={antenna.get('title')} to={`/antennas/${antenna.get('id')}`} transparent />
      ))}
    </div>
  );
};
