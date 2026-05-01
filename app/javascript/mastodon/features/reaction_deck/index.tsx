/* eslint-disable @typescript-eslint/no-unsafe-return,
                  @typescript-eslint/no-explicit-any,
                  @typescript-eslint/no-unsafe-call,
                  @typescript-eslint/no-unsafe-member-access,
                  @typescript-eslint/no-unsafe-assignment,
                  @typescript-eslint/no-confusing-void-expression */

import type { ReactNode } from 'react';
import { useState, useCallback } from 'react';
import { createPortal } from 'react-dom';

import { FormattedMessage, defineMessages, useIntl } from 'react-intl';

import { Helmet } from 'react-helmet';

import type {
  DragStartEvent,
  DragEndEvent,
  UniqueIdentifier,
  // Announcements,
  // ScreenReaderInstructions,
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
import type { CustomEmoji } from 'emoji-mart';

import MenuIcon from '@/material-icons/400-24px/menu.svg?react';
import EmojiReactionIcon from '@/material-icons/400-24px/mood.svg?react';
import { updateReactionDeck } from 'mastodon/actions/reaction_deck';
import { Button } from 'mastodon/components/button';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import EmojiPickerDropdown from 'mastodon/features/compose/containers/emoji_picker_dropdown_container';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import emojify from '../emoji/emoji';
import { usePickerEmojis } from '../emoji/picker';

const messages = defineMessages({
  reaction_deck_add: { id: 'reaction_deck.add', defaultMessage: 'Add' },
  heading: { id: 'column.reaction_deck', defaultMessage: 'Reaction deck' },
});

const ReactionEmoji: React.FC<{
  index: number;
  emoji: string;
  mapEmoji?: CustomEmoji;
  overlay?: boolean;
  onChange?: (index: number, emoji: any) => void;
  onRemove?: (index: number) => void;
}> = ({ index, emoji, mapEmoji, overlay, onChange, onRemove }) => {
  const handleChange = useCallback(
    (emoji: any) => {
      if (onChange) onChange(index, emoji);
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
    const filename = mapEmoji.imageUrl;
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
            <EmojiPickerDropdown onPickEmoji={handleChange} />
            <div>{content}</div>
          </div>
          <div className='reaction_deck__emoji__wrapper__options'>
            <Button secondary text={'Remove'} onClick={handleRemove} />
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

  const { customEmojis } = usePickerEmojis();
  const deck = useAppSelector((state) => state.reaction_deck);

  const onChange = useCallback(
    (emojis: any) => {
      dispatch(updateReactionDeck(emojis));
    },
    [dispatch],
  );

  const deckToArray = (deckData: any) =>
    deckData.map((item: any) => item.get('name')).toArray();

  const handleChange = useCallback(
    (index: number, emoji: any) => {
      const newDeck = deckToArray(deck);
      newDeck[index] = emoji.native || emoji.id.replace(':', '');
      onChange(newDeck);
    },
    [onChange, deck],
  );

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

  const [activeId, setActiveId] = useState<UniqueIdentifier | null>(null);
  const [activeEmoji, setActiveEmoji] = useState<any>(null);

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
      setActiveEmoji(deck.get(idToNumber(active.id)));
    },
    [setActiveId, setActiveEmoji, deck],
  );

  const handleDragEnd = useCallback(
    (e: DragEndEvent) => {
      const { active, over } = e;

      if (over && active.id !== over.id) {
        const newDeck = deckToArray(deck);
        const old = newDeck[idToNumber(active.id)];
        newDeck[idToNumber(active.id)] = newDeck[idToNumber(over.id)];
        newDeck[idToNumber(over.id)] = old;

        onChange(newDeck);
      }

      setActiveId(null);
      setActiveEmoji(null);
    },
    [setActiveId, setActiveEmoji, onChange, deck],
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

      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={handleDragStart}
        onDragEnd={handleDragEnd}
        modifiers={[restrictToVerticalAxis]}
      >
        <SortableContext items={deck.toArray()} strategy={rectSortingStrategy}>
          {deck.map((emoji: any, index) => (
            <div key={index} id={index.toString()}>
              <ReactionEmoji
                mapEmoji={customEmojis?.find((c) => c.id === emoji.get('name'))}
                emoji={emoji.get('name')}
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
                  mapEmoji={customEmojis?.find(
                    (c) => c.id === activeEmoji.get('name'),
                  )}
                  emoji={activeEmoji.get('name')}
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
