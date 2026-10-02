import { useCallback } from 'react';

import classNames from 'classnames';

import type { Record as ImmutableRecord } from 'immutable';

import { isHideItem } from 'mastodon/initial_state';

import { emojiReact, unEmojiReact } from '../actions/interactions';
import type { ApiStatusEmojiReactionRowJSON } from '../api_types/statuses';
import type { StatusShape } from '../models/status';
import { makeGetStatus } from '../selectors';
import { useAppDispatch, useAppSelector } from '../store';

import { EmojiView } from './emoji_view';

interface ButtonProps {
  name: string;
  domain: string;
  url: string;
  staticUrl: string;
  count?: number;
  me: boolean;
  onEmojiReact: (code: string) => void;
  onUnEmojiReact: (code: string) => void;
}

export const EmojiReactionButton: React.FC<ButtonProps> = ({
  name,
  domain,
  url,
  staticUrl,
  count,
  me,
  onEmojiReact,
  onUnEmojiReact,
}) => {
  const onClick = useCallback(() => {
    const nameParameter = domain ? `${name}@${domain}` : name;
    if (me) {
      onUnEmojiReact(nameParameter);
    } else {
      onEmojiReact(nameParameter);
    }
  }, [domain, name, me]);

  const classList = {
    'emoji-reactions-bar__button': true,
    toggled: me,
  };

  const countView = count !== undefined && (
    <span className='count'>{count}</span>
  );

  return (
    <button className={classNames(classList)} type='button' onClick={onClick}>
      <span className='emoji'>
        <EmojiView name={name} url={url} staticUrl={staticUrl} />
      </span>
      {countView}
    </button>
  );
};

interface BarProps {
  emojiReactions: ApiStatusEmojiReactionRowJSON[];
  statusId: string;
  myReactionOnly?: boolean;
}

const getStatus = makeGetStatus();

export const StatusEmojiReactionsBar: React.FC<BarProps> = ({
  emojiReactions,
  statusId,
  myReactionOnly,
}) => {
  const dispatch = useAppDispatch();

  const statusImmutable = useAppSelector(
    (state) =>
      // @ts-expect-error getStatus isn't properly typed yet
      getStatus(state, { id: statusId }) as
        | ImmutableRecord<StatusShape>
        | undefined,
  );

  const onEmojiReact = useCallback(
    (code: string) => {
      dispatch(emojiReact(statusImmutable, code));
    },
    [statusImmutable, dispatch],
  );

  const onUnEmojiReact = useCallback(
    (code: string) => {
      dispatch(unEmojiReact(statusImmutable, code));
    },
    [statusImmutable, dispatch],
  );

  if (!statusImmutable) {
    return;
  }

  const isShowCount = !isHideItem('emoji_reaction_count');

  const emojiButtons = Array.from(emojiReactions)
    .filter((emoji) => emoji.count !== 0)
    .filter((emoji) => !myReactionOnly || emoji.me)
    .map((emoji, index) => (
      <EmojiReactionButton
        key={index}
        name={emoji.name}
        count={isShowCount ? (myReactionOnly ? 1 : emoji.count) : undefined}
        me={emoji.me}
        url={emoji.url}
        staticUrl={emoji.static_url}
        domain={emoji.domain}
        onEmojiReact={onEmojiReact}
        onUnEmojiReact={onUnEmojiReact}
      />
    ));

  return <div className='status__emoji-reactions-bar'>{emojiButtons}</div>;
};
