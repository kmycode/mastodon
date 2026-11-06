import { createDataLoadingThunk } from 'mastodon/store/typed_functions';

import { apiGetDeck, apiUpdateDeck } from '../api/reaction_deck';

export const fetchReactionDeck = createDataLoadingThunk(
  'reaction_deck/fetch',
  async () => await apiGetDeck(),
);

export const updateReactionDeck = createDataLoadingThunk(
  'reaction_deck/update',
  async ({ emojis }: { emojis: string[] }) => await apiUpdateDeck(emojis),
);
