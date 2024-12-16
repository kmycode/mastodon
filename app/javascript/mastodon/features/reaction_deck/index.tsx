/* eslint-disable @typescript-eslint/no-unsafe-return,
                  @typescript-eslint/no-explicit-any,
                  @typescript-eslint/no-unsafe-call,
                  @typescript-eslint/no-unsafe-member-access,
                  @typescript-eslint/no-unsafe-assignment */

import type { ReactNode } from 'react';
import { useCallback } from 'react';

import { FormattedMessage, defineMessages, useIntl } from 'react-intl';

import { Helmet } from 'react-helmet';

import EmojiReactionIcon from '@/material-icons/400-24px/mood.svg?react';
import { updateReactionDeck } from 'mastodon/actions/reaction_deck';
import { Button } from 'mastodon/components/button';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import EmojiPickerDropdown from 'mastodon/features/compose/containers/emoji_picker_dropdown_container';
import { autoPlayGif } from 'mastodon/initial_state';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import emojify from '../emoji/emoji';

const messages = defineMessages({
  reaction_deck_add: { id: 'reaction_deck.add', defaultMessage: 'Add' },
  heading: { id: 'column.reaction_deck', defaultMessage: 'Reaction deck' },
});

const ReactionEmoji: React.FC<{
  index: number;
  emoji: string;
  emojiMap: any;
  onRemove: (index: number) => void;
}> = ({ index, emoji, emojiMap, onRemove }) => {
  const handleRemove = useCallback(() => {
    onRemove(index);
  }, [index, onRemove]);

  let content: ReactNode;
  const mapEmoji = emojiMap.find((e: any) => e.get('shortcode') === emoji);

  if (mapEmoji) {
    const filename = autoPlayGif
      ? mapEmoji.get('url')
      : mapEmoji.get('static_url');
    const shortCode = `:${emoji}:`;

    content = (
      <img
        draggable='false'
        className='emojione custom-emoji'
        alt={shortCode}
        title={shortCode}
        src={filename}
      />
    );
  } else {
    const html = { __html: emojify(emoji) };
    content = <span dangerouslySetInnerHTML={html} />;
  }

  return (
    <div className='reaction_emoji reaction_deck__emoji'>
      <div className='reaction_deck__emoji__wrapper'>
        <div className='reaction_deck__emoji__wrapper__options'>
          <Button secondary onClick={handleRemove}>
            {content}
          </Button>
        </div>
      </div>
    </div>
  );
};

export const ReactionDeck: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const intl = useIntl();

  const emojiMap = useAppSelector((state) => state.custom_emojis);
  const deck = useAppSelector((state) => state.reaction_deck);

  const onChange = useCallback(
    (emojis: any) => {
      dispatch(updateReactionDeck(emojis));
    },
    [dispatch],
  );

  const deckToArray = (deckData: any) =>
    deckData.map((item: any) => item.get('name')).toArray();

  /*
  const handleReorder = useCallback((result: any) => {
    const newDeck = deckToArray(deck);
    const deleted = newDeck.splice(result.source.index, 1);
    newDeck.splice(result.destination.index, 0, deleted[0]);
    onChange(newDeck);
  }, [onChange, deck]);
  */

  const handleRemove = useCallback(
    (index: number) => {
      const newDeck = deckToArray(deck);
      newDeck.splice(index, 1);
      onChange(newDeck);
    },
    [onChange, deck],
  );

  const handleAdd = useCallback(
    (emoji: any) => {
      const newDeck = deckToArray(deck);
      const newEmoji = emoji.native || emoji.id.replace(':', '');
      newDeck.push(newEmoji);
      onChange(newDeck);
    },
    [onChange, deck],
  );

  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
  if (!deck) {
    return (
      <Column>
        <LoadingIndicator />
      </Column>
    );
  }

  return (
    <Column bindToDocument={!multiColumn}>
      <ColumnHeader
        icon='smile-o'
        iconComponent={EmojiReactionIcon}
        title={intl.formatMessage(messages.heading)}
        multiColumn={multiColumn}
        showBackButton
      />

      {deck.map((emoji: any, index) => (
        <ReactionEmoji
          emojiMap={emojiMap}
          key={index}
          emoji={emoji.get('name')}
          index={index}
          onRemove={handleRemove}
        />
      ))}

      <div>
        <EmojiPickerDropdown
          onPickEmoji={handleAdd}
          button={
            <Button secondary>
              <FormattedMessage id='reaction_deck.add' defaultMessage='Add' />
            </Button>
          }
        />
      </div>

      <Helmet>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default ReactionDeck;
