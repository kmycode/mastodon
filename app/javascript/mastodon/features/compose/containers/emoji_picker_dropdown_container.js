import { createSelector } from '@reduxjs/toolkit';
import { Map as ImmutableMap, List as ImmutableList } from 'immutable';
import { connect } from 'react-redux';


import { isHideItem } from 'mastodon/initial_state';

import { emojiUse } from '../../../actions/emojis';
import { changeSetting } from '../../../actions/settings';
import EmojiPickerDropdown from '../components/emoji_picker_dropdown';
import data from 'emoji-mart/data/all.json';
import { getEmojiDataFromNative } from 'emoji-mart';



const perLine = 8;
const lines   = 2;

const DEFAULTS = [
  '+1',
  'grinning',
  'kissing_heart',
  'heart_eyes',
  'laughing',
  'stuck_out_tongue_winking_eye',
  'sweat_smile',
  'joy',
  'yum',
  'disappointed',
  'thinking_face',
  'weary',
  'sob',
  'sunglasses',
  'heart',
  'ok_hand',
];

const RECENT_SIZE = DEFAULTS.length;

const getFrequentlyUsedEmojis = createSelector([
  state => state.getIn(['settings', 'frequentlyUsedEmojis'], ImmutableMap()),
  state => state.get('reaction_deck', ImmutableList()),
], (emojiCounters, reactionDeck) => {
  let deckEmojis = reactionDeck
    .toArray()
    .map((e) => e.get('name'))
    .filter((e) => e)
    .map((e) => getEmojiDataFromNative(e, 'apple', data)?.id ?? e);
  deckEmojis = [...new Set(deckEmojis)];

  let emojis;
  if (!isHideItem('recent_emojis')) {
    emojis = emojiCounters
      .keySeq()
      .filter((ee) => deckEmojis.indexOf(ee) < 0)
      .sort((a, b) => emojiCounters.get(a) - emojiCounters.get(b))
      .reverse()
      .slice(0, perLine * lines)
      .toArray();

    if (emojis.length < RECENT_SIZE) {
      let uniqueDefaults = DEFAULTS.filter(emoji => !emojis.includes(emoji));
      emojis = emojis.concat(uniqueDefaults.slice(0, RECENT_SIZE - emojis.length));
    }
  } else {
    emojis = [];
  }

  emojis = deckEmojis.concat(emojis);

  if (emojis.length <= 0) emojis = ['+1'];

  return emojis;
});

const mapStateToProps = state => ({
  skinTone: state.getIn(['settings', 'skinTone']),
  frequentlyUsedEmojis: getFrequentlyUsedEmojis(state),
});

const mapDispatchToProps = (dispatch, { onPickEmoji }) => ({
  onSkinTone: skinTone => {
    dispatch(changeSetting(['skinTone'], skinTone));
  },

  onPickEmoji: emoji => {
    dispatch(emojiUse(emoji));

    if (onPickEmoji) {
      onPickEmoji(emoji);
    }
  },
});

export default connect(mapStateToProps, mapDispatchToProps)(EmojiPickerDropdown);
