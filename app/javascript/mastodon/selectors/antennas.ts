import type { Map as ImmutableMap, List as ImmutableList } from 'immutable';

import type { Antenna } from 'mastodon/models/antenna';
import { createAppSelector } from 'mastodon/store';

const getAntennas = createAppSelector(
  [(state) => state.antennas],
  (antennas: ImmutableMap<string, Antenna | null>): ImmutableList<Antenna> =>
    antennas.toList().filter((item: Antenna | null): item is Antenna => !!item),
);

export const getOrderedAntennas = createAppSelector(
  [(state) => getAntennas(state)],
  (antennas) =>
    antennas
      .sort((a: Antenna, b: Antenna) => a.title.localeCompare(b.title))
      .toArray(),
);

export const getFavouritedAntennas = createAppSelector(
  [(state) => getAntennas(state)],
  (antennas) =>
    antennas
      .sort((a: Antenna, b: Antenna) => a.title.localeCompare(b.title))
      .filter((antenna) => antenna.favourite)
      .toArray(),
);
