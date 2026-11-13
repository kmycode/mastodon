import type { ReactNode } from 'react';
import { useState, useCallback } from 'react';
import { createPortal } from 'react-dom';

import { defineMessages, useIntl } from 'react-intl';

import type {
  DragStartEvent,
  DragEndEvent,
  UniqueIdentifier,
} from '@dnd-kit/core';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
} from '@dnd-kit/core';
import { restrictToVerticalAxis } from '@dnd-kit/modifiers';
import {
  SortableContext,
  sortableKeyboardCoordinates,
  rectSortingStrategy,
  useSortable,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Helmet } from '@unhead/react/helmet';
import type { EmojiData } from 'emoji-mart';

import type { ApiReactionDeckItemJSON } from '@/mastodon/api_types/reaction_deck';
import { Emoji } from '@/mastodon/components/emoji';
import {
  EmojiPickerButton,
  emojiToStringForEmojiReactionApi,
} from '@/mastodon/components/emoji/picker';
import { useCustomEmojis } from '@/mastodon/hooks/useCustomEmojis';
import { autoPlayGif } from '@/mastodon/initial_state';
import MenuIcon from '@/material-icons/400-24px/menu.svg?react';
import { updateReactionDeck } from 'mastodon/actions/reaction_deck_typed';
import { Button } from 'mastodon/components/button';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import type { CustomEmojiData } from '../emoji/types';

interface ReactionDeckItem {
  id: number;
  name: string;
}

const messages = defineMessages({
  reaction_deck_add: { id: 'reaction_deck.add', defaultMessage: 'Add' },
  heading: { id: 'column.reaction_deck', defaultMessage: 'Reaction deck' },
});

const ReactionEmoji: React.FC<{
  index: number;
  emoji: string;
  mapEmoji?:
    | Pick<CustomEmojiData, 'url' | 'static_url' | 'shortcode'>
    | undefined;
  overlay?: boolean;
  onChange?: (index: number, emoji: string) => void;
  onRemove?: (index: number) => void;
}> = ({ index, emoji, mapEmoji, overlay, onChange, onRemove }) => {
  const onEmojiPick = useCallback(
    (emoji: EmojiData) => {
      onChange?.(index, emojiToStringForEmojiReactionApi(emoji));
    },
    [index, onChange],
  );

  const handleRemove = useCallback(() => {
    if (onRemove) onRemove(index);
  }, [index, onRemove]);

  const { attributes, listeners, setNodeRef, transform, transition } =
    useSortable({ id: index.toString() });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  let content: ReactNode;

  if (mapEmoji) {
    const filename = autoPlayGif ? mapEmoji.url : mapEmoji.static_url;
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
    content = <Emoji code={emoji} />;
  }

  if (overlay) {
    return (
      <div className='reaction_deck_container__row__overlay'>{content}</div>
    );
  }

  return (
    <div
      className='reaction_deck_container__row'
      ref={setNodeRef}
      style={style}
      {...attributes}
    >
      <span {...listeners}>
        <Icon id='bars' icon={MenuIcon} className='handle' />
      </span>
      <div className='reaction_deck__emoji'>
        <div className='reaction_deck__emoji__wrapper'>
          <div className='reaction_deck__emoji__wrapper__content'>
            <EmojiPickerButton onPick={onEmojiPick} />
            <div>{content}</div>
          </div>
          <div className='reaction_deck__emoji__wrapper__options'>
            <Button onClick={handleRemove}>{'Remove'}</Button>
          </div>
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

  const customEmojis = useCustomEmojis();
  const deckLoading = useAppSelector((state) => state.reaction_deck.loading);
  const deck = useAppSelector((state) => state.reaction_deck.items).map(
    (item, index) => ({ ...item, id: index + 1 }),
  ) satisfies ReactionDeckItem[];

  const onChange = useCallback(
    (emojis: string[]) => {
      void dispatch(updateReactionDeck({ emojis }));
    },
    [dispatch],
  );

  const deckToEmojiNameArray = (deckData: ApiReactionDeckItemJSON[]) =>
    deckData.map((item: ApiReactionDeckItemJSON) => item.name);

  const handleChange = useCallback(
    (index: number, emoji: string) => {
      const newDeck = deckToEmojiNameArray(deck);
      newDeck[index] = emoji;
      onChange(newDeck);
    },
    [onChange, deck],
  );

  const handleRemove = useCallback(
    (index: number) => {
      const newDeck = deckToEmojiNameArray(deck);
      newDeck.splice(index, 1);
      onChange(newDeck);
    },
    [onChange, deck],
  );

  const handleAdd = useCallback(
    (emoji: EmojiData) => {
      const newDeck = deckToEmojiNameArray(deck);
      const newEmoji = emojiToStringForEmojiReactionApi(emoji);
      newDeck.push(newEmoji);
      onChange(newDeck);
    },
    [onChange, deck],
  );

  const [activeId, setActiveId] = useState<UniqueIdentifier | null>(null);
  const [activeEmoji, setActiveEmoji] = useState<
    ReactionDeckItem | undefined | null
  >(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 5,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  const idToNumber = (id: UniqueIdentifier): number => {
    if (typeof id === 'string') {
      return parseInt(id);
    }
    if (typeof id === 'number') {
      return id;
    }
    return 0;
  };

  const handleDragStart = useCallback(
    (e: DragStartEvent) => {
      const { active } = e;

      setActiveId(active.id);
      setActiveEmoji(deck[idToNumber(active.id)]);
    },
    [setActiveId, setActiveEmoji, deck],
  );

  const handleDragEnd = useCallback(
    (e: DragEndEvent) => {
      const { active, over } = e;

      if (over && active.id !== over.id) {
        const newDeck = deckToEmojiNameArray(deck);
        const old = newDeck[idToNumber(active.id)];
        const overItem = newDeck[idToNumber(over.id)];

        if (overItem && old) {
          newDeck[idToNumber(active.id)] = overItem;
          newDeck[idToNumber(over.id)] = old;

          onChange(newDeck);
        }
      }

      setActiveId(null);
      setActiveEmoji(null);
    },
    [setActiveId, setActiveEmoji, onChange, deck],
  );

  if (deckLoading) {
    return (
      <Column>
        <LoadingIndicator />
      </Column>
    );
  }

  return (
    <Column bindToDocument={!multiColumn}>
      <ColumnHeader
        title={intl.formatMessage(messages.heading)}
        withBackButton
      />

      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={handleDragStart}
        onDragEnd={handleDragEnd}
        modifiers={[restrictToVerticalAxis]}
      >
        <SortableContext items={deck} strategy={rectSortingStrategy}>
          {deck.map((emoji: ReactionDeckItem, index) => (
            <div key={emoji.id} id={`reaction-deck-item-${index.toString()}`}>
              <ReactionEmoji
                mapEmoji={customEmojis[emoji.name]}
                emoji={emoji.name}
                index={index}
                onChange={handleChange}
                onRemove={handleRemove}
              />
            </div>
          ))}
        </SortableContext>

        {createPortal(
          <DragOverlay>
            {activeId ? (
              <div style={{ position: 'fixed' }}>
                <ReactionEmoji
                  mapEmoji={customEmojis[activeEmoji?.name ?? 0]}
                  emoji={activeEmoji?.name ?? ''}
                  index={-1}
                  overlay
                />
              </div>
            ) : null}
          </DragOverlay>,
          document.body,
        )}
      </DndContext>

      <div>
        <EmojiPickerButton onPick={handleAdd} />
      </div>

      <Helmet>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default ReactionDeck;
