import { useEffect, useState } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import { fetchAntennas } from '@/mastodon/actions/antennas_typed';
import AntennaIcon from '@/material-icons/400-24px/wifi.svg?react';
import { ColumnLink } from 'mastodon/features/ui/components/column_link';
import { getFavouritedAntennas } from 'mastodon/selectors/antennas';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import { CollapsiblePanel } from './collapsible_panel';

const messages = defineMessages({
  antennas: { id: 'navigation_bar.antennas', defaultMessage: 'Antennas' },
  expand: {
    id: 'navigation_panel.expand_lists',
    defaultMessage: 'Expand list menu',
  },
  collapse: {
    id: 'navigation_panel.collapse_lists',
    defaultMessage: 'Collapse list menu',
  },
});

export const AntennaPanel: React.FC = () => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const antennas = useAppSelector((state) => getFavouritedAntennas(state));
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setLoading(true);

    void dispatch(fetchAntennas()).then(() => {
      setLoading(false);

      return '';
    });
  }, [dispatch, setLoading]);

  return (
    <CollapsiblePanel
      to='/antennas'
      icon='list-ul'
      iconComponent={AntennaIcon}
      activeIconComponent={AntennaIcon}
      title={intl.formatMessage(messages.antennas)}
      collapseTitle={intl.formatMessage(messages.collapse)}
      expandTitle={intl.formatMessage(messages.expand)}
      loading={loading}
    >
      {antennas.map((antenna) => (
        <ColumnLink
          icon='list-ul'
          key={antenna.id}
          iconComponent={AntennaIcon}
          activeIconComponent={AntennaIcon}
          text={antenna.title}
          to={`/antennas/${antenna.id}`}
          transparent
        />
      ))}
    </CollapsiblePanel>
  );
};
