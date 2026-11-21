import { createReducer } from '@reduxjs/toolkit';

import {
  fetchReactionDeck,
  updateReactionDeck,
} from '../actions/reaction_deck_typed';
import type { ApiReactionDeckItemJSON } from '../api_types/reaction_deck';

export interface ReactionDeckData {
  items: ApiReactionDeckItemJSON[];
  loading: boolean;
}

const initialState: ReactionDeckData = {
  items: [],
  loading: false,
};

export const reactionDeckReducer = createReducer(initialState, (builder) => {
  builder
    .addCase(fetchReactionDeck.pending, (state) => {
      state.loading = true;
    })
    .addCase(fetchReactionDeck.rejected, (state) => {
      state.loading = false;
    })
    .addCase(fetchReactionDeck.fulfilled, (state, action) => {
      const { emojis } = action.payload;

      state.items = emojis;
      state.loading = false;
    })
    .addCase(updateReactionDeck.pending, (state) => {
      state.loading = true;
    })
    .addCase(updateReactionDeck.rejected, (state) => {
      state.loading = true;
    })
    .addCase(updateReactionDeck.fulfilled, (state, action) => {
      const { emojis } = action.payload;

      state.items = emojis;
      state.loading = false;
    });
});
