import type { RecordOf } from 'immutable';
import { Record } from 'immutable';

import type { ApiAntennaJSON } from 'mastodon/api_types/antennas';

type AntennaShape = Required<ApiAntennaJSON>; // no changes from server shape
export type Antenna = RecordOf<AntennaShape>;

const AntennaFactory = Record<AntennaShape>({
  id: '',
  title: '',
  stl: false,
  ltl: false,
  insert_feeds: false,
  with_media_only: false,
  ignore_reblog: false,
  favourite: true,
  list: null,
  list_id: undefined,
});

export function createAntenna(attributes: Partial<AntennaShape>) {
  return AntennaFactory(attributes);
}
