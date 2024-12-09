// See app/serializers/rest/antenna_serializer.rb

import type { ApiListJSON } from './lists';

export interface ApiAntennaJSON {
  id: string;
  title: string;
  stl: boolean;
  ltl: boolean;
  insert_feeds: boolean;
  with_media_only: boolean;
  ignore_reblog: boolean;
  favourite: boolean;
  list: ApiListJSON | null;

  list_id: string | undefined;
}
