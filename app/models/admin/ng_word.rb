# frozen_string_literal: true

class Admin::NgWord
  class << self
    def reject?(text)
      ng_words.any? { |word| include?(text, word) }
    end

    def reject_with_custom_words?(text, custom_ng_words)
      custom_ng_words.any? { |word| include?(text, word) }
    end

    def hashtag_reject?(hashtag_count)
      post_hash_tags_max.positive? && post_hash_tags_max < hashtag_count
    end

    def hashtag_reject_with_extractor?(text)
      hashtag_reject?(Extractor.extract_hashtags(text)&.size || 0)
    end

    def stranger_mention_reject?(text)
      ng_words_for_stranger_mention.any? { |word| include?(text, word) }
    end

    private

    def include?(text, word)
      if word.start_with?('?') && word.size >= 2
        text =~ /#{word[1..]}/i
      else
        text.include?(word)
      end
    end

    def ng_words
      Setting.ng_words || []
    end

    def ng_words_for_stranger_mention
      Setting.ng_words_for_stranger_mention || []
    end

    def post_hash_tags_max
      value = Setting.post_hash_tags_max
      value.is_a?(Integer) && value.positive? ? value : 0
    end
  end
end
