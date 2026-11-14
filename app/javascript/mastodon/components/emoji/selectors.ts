import { isHideItem } from '@/mastodon/initial_state';
import { createAppSelector } from '@/mastodon/store/typed_functions';

export const PER_LINE = 8;
export const LINES = 2;

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

export const selectFrequentlyUsedEmoji = createAppSelector(
  [
    (state) =>
      state.settings.get('frequentlyUsedEmojis') as
        | Immutable.Map<string, number>
        | undefined,
    (state) => state.reaction_deck.items,
  ],
  (emojiCounters, deck) => {
    const deckEmojis = deck.map((d) => d.name);

    if (isHideItem('recent_emojis')) {
      return deckEmojis;
    }

    if (!emojiCounters) {
      return deckEmojis.concat(DEFAULTS);
    }

    let emojis = emojiCounters
      .toArray()
      .sort((a, b) => a[1] - b[1])
      .reverse()
      .slice(0, PER_LINE * LINES)
      .map(([emoji]) => emoji);

    if (emojis.length < DEFAULTS.length) {
      const uniqueDefaults = DEFAULTS.filter(
        (emoji) => !emojis.includes(emoji),
      );
      emojis = emojis.concat(
        uniqueDefaults.slice(0, DEFAULTS.length - emojis.length),
      );
    }

    return deckEmojis.concat(emojis);
  },
);
