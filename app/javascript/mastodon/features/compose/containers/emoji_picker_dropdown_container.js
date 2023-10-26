import { Map as ImmutableMap, List as ImmutableList } from 'immutable';
import { connect } from 'react-redux';
import { createSelector } from 'reselect';

import { hideRecentEmojis } from 'mastodon/initial_state';

import { useEmoji } from '../../../actions/emojis';
import { changeSetting } from '../../../actions/settings';
import { unicodeMapping } from '../../emoji/emoji_unicode_mapping_light';
import EmojiPickerDropdown from '../components/emoji_picker_dropdown';



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
  state => { return {
    emojiCounters: state.getIn(['settings', 'frequentlyUsedEmojis'], ImmutableMap()),
    reactionDeck: state.get('reaction_deck', ImmutableList()),
  }; },
], data => {
  const { emojiCounters, reactionDeck } = data;

  let deckEmojis = reactionDeck
    .toArray()
    .map((e) => e.get('name'))
    .filter((e) => e)
    .map((e) => unicodeMapping[e] ? unicodeMapping[e].shortCode : e);
  deckEmojis = [...new Set(deckEmojis)];

  let emojis;
  if (!hideRecentEmojis) {
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

const getCustomEmojis = createSelector([
  state => state.get('custom_emojis'),
], emojis => emojis.filter(e => e.get('visible_in_picker')).sort((a, b) => {
  const aShort = a.get('shortcode').toLowerCase();
  const bShort = b.get('shortcode').toLowerCase();

  if (aShort < bShort) {
    return -1;
  } else if (aShort > bShort ) {
    return 1;
  } else {
    return 0;
  }
}));

const mapStateToProps = state => ({
  custom_emojis: getCustomEmojis(state),
  skinTone: state.getIn(['settings', 'skinTone']),
  frequentlyUsedEmojis: getFrequentlyUsedEmojis(state),
});

const mapDispatchToProps = (dispatch, { onPickEmoji }) => ({
  onSkinTone: skinTone => {
    dispatch(changeSetting(['skinTone'], skinTone));
  },

  onPickEmoji: emoji => {
    // eslint-disable-next-line react-hooks/rules-of-hooks -- this is not a react hook
    dispatch(useEmoji(emoji));

    if (onPickEmoji) {
      onPickEmoji(emoji);
    }
  },
});

export default connect(mapStateToProps, mapDispatchToProps)(EmojiPickerDropdown);
