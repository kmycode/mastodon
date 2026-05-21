import type { CustomEmojiMapArg } from '../features/emoji/types';

import { EmojiHTML } from './emoji/html';

interface EmojiViewProps {
  name: string;
  url?: string;
  staticUrl?: string;
}

export const EmojiView: React.FC<EmojiViewProps> = ({
  name,
  url,
  staticUrl,
}) => {
  if (url && staticUrl) {
    const extraEmojis: CustomEmojiMapArg = [
      {
        shortcode: name,
        static_url: staticUrl,
        url,
        visible_in_picker: false,
      },
    ];
    return <EmojiHTML htmlString={`:${name}:`} extraEmojis={extraEmojis} />;
  }

  return <EmojiHTML htmlString={name} className='unicode' />;
};
