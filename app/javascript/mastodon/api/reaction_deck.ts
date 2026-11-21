import api from 'mastodon/api';

import type { ApiReactionDeckItemJSON } from '../api_types/reaction_deck';

export const apiGetDeck = async () => {
  const response = await api().request<ApiReactionDeckItemJSON[]>({
    method: 'GET',
    url: '/api/v1/reaction_deck',
  });

  return {
    emojis: response.data,
  };
};

export const apiUpdateDeck = async (emojis: string[]) => {
  const response = await api().request<ApiReactionDeckItemJSON[]>({
    method: 'POST',
    url: '/api/v1/reaction_deck',
    params: { emojis },
  });

  return {
    emojis: response.data,
  };
};
