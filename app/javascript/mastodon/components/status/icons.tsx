import {
  ArrowsClockwiseIcon,
  BookmarkSimpleIcon,
  ChatCircleIcon,
  HeartIcon,
  QuotesIcon,
} from '@phosphor-icons/react';

import MoodIcon from '@/material-icons/400-20px/mood.svg?react';

import { iconWeight } from '../icon';

export const StatusReplyIcon = ChatCircleIcon;
export const StatusReplyAllIcon = StatusReplyIcon;
export const StatusQuoteIcon = QuotesIcon;
export const StatusBoostIcon = ArrowsClockwiseIcon;
export const StatusBoostActiveIcon = iconWeight(ArrowsClockwiseIcon, 'bold');
export const StatusLikeIcon = HeartIcon;
export const StatusLikeActiveIcon = iconWeight(HeartIcon, 'fill');
export const StatusBookmarkIcon = BookmarkSimpleIcon;
export const StatusBookmarkActiveIcon = iconWeight(BookmarkSimpleIcon, 'fill');
export const StatusEmojiReactionIcon = MoodIcon;
