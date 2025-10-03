import type { ApiCustomEmojiJSON } from './custom_emoji';

export interface ApiAccountFieldJSON {
  name: string;
  value: string;
  verified_at: string | null;
}

export interface ApiAccountRoleJSON {
  color: string;
  id: string;
  name: string;
}

export interface ApiAccountOtherSettingsJSON {
  noindex: boolean;
  hide_network: boolean;
  hide_statuses_count: boolean;
  hide_following_count: boolean;
  hide_followers_count: boolean;
  translatable_private: boolean;
  link_preview: boolean;
  emoji_reaction_policy:
    | 'allow'
    | 'outside_only'
    | 'following_only'
    | 'followers_only'
    | 'mutuals_only'
    | 'block';
  subscription_policy: 'allow' | 'followers_only' | 'block';
}

export interface ApiServerFeaturesJSON {
  circle: boolean;
  emoji_reaction: boolean;
  status_reference: boolean;
  legacy_quote: boolean;
}

// See app/serializers/rest/account_serializer.rb
export interface BaseApiAccountJSON {
  acct: string;
  avatar: string;
  avatar_static: string;
  bot: boolean;
  created_at: string;
  discoverable?: boolean;
  indexable: boolean;
  display_name: string;
  emojis: ApiCustomEmojiJSON[];
  fields: ApiAccountFieldJSON[];
  followers_count: number;
  following_count: number;
  group: boolean;
  header: string;
  header_static: string;
  id: string;
  last_status_at: string;
  locked: boolean;
  noindex?: boolean;
  note: string;
  other_settings: ApiAccountOtherSettingsJSON;
  roles?: ApiAccountJSON[];
  server_features: ApiServerFeaturesJSON;
  software: string;
  statuses_count: number;
  uri: string;
  url?: string;
  username: string;
  moved?: ApiAccountJSON;
  suspended?: boolean;
  limited?: boolean;
  memorial?: boolean;
  hide_collections: boolean;
}

// See app/serializers/rest/muted_account_serializer.rb
export interface ApiMutedAccountJSON extends BaseApiAccountJSON {
  mute_expires_at?: string | null;
}

// For now, we have the same type representing both `Account` and `MutedAccount`
// objects, but we should refactor this in the future.
export type ApiAccountJSON = ApiMutedAccountJSON;

// See app/serializers/rest/familiar_followers_serializer.rb
export type ApiFamiliarFollowersJSON = {
  id: string;
  accounts: ApiAccountJSON[];
}[];
