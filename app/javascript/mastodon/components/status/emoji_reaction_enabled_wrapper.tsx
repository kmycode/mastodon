import { useAccount } from '@/mastodon/hooks/useAccount';
import { enableEmojiReaction, isHideItem, me } from '@/mastodon/initial_state';
import { useAppSelector } from '@/mastodon/store';

export const EmojiReactionEnabledWrapper: React.FC<{
  children: React.ReactNode;
  accountId: string;
}> = ({ children, accountId }) => {
  const account = useAccount(accountId);
  const relationship = useAppSelector((state) =>
    state.relationships.get(accountId),
  );
  if (!account) return;

  const writtenByMe = accountId === me;
  const emojiReactionAvailableServer =
    !isHideItem('emoji_reaction_unavailable_server') ||
    account.server_features.emoji_reaction;
  const emojiReactionPolicy =
    account.other_settings.emoji_reaction_policy || 'allow'; // eslint-disable-line @typescript-eslint/no-unnecessary-condition
  const following =
    emojiReactionPolicy !== 'followers_only' || relationship?.following;
  const followed =
    emojiReactionPolicy !== 'following_only' || relationship?.followed_by;
  const mutual =
    emojiReactionPolicy !== 'mutuals_only' ||
    (relationship && relationship.following && relationship.followed_by);
  const outside =
    emojiReactionPolicy !== 'outside_only' ||
    (relationship && (relationship.following || relationship.followed_by));
  const denyFromAll = emojiReactionPolicy !== 'block';
  const isEnableEmojiReaction =
    enableEmojiReaction &&
    emojiReactionAvailableServer &&
    denyFromAll &&
    (writtenByMe || (following && followed && mutual && outside));

  return isEnableEmojiReaction ? children : null;
};
