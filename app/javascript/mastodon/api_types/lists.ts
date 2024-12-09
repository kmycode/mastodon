// See app/serializers/rest/list_serializer.rb

import type { ApiAntennaJSON } from './antennas';

export type RepliesPolicyType = 'list' | 'followed' | 'none';

export interface ApiListJSON {
  id: string;
  title: string;
  exclusive: boolean;
  replies_policy: RepliesPolicyType;
  notify: boolean;
  favourite: boolean;
  antennas?: ApiAntennaJSON[];
}
