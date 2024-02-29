# frozen_string_literal: true

class Admin::NgWord
  class << self
    def reject?(text, **options)
      text = PlainTextFormatter.new(text, false).to_s if options[:uri].present?
      hit_word = ng_words.detect { |word| include?(text, word) ? word : nil }
      record!(:ng_words, text, hit_word, options) if hit_word.present?
      hit_word.present?
    end

    def stranger_mention_reject?(text, **options)
      text = PlainTextFormatter.new(text, false).to_s if options[:uri].present?
      hit_word = ng_words_for_stranger_mention.detect { |word| include?(text, word) ? word : nil }
      record!(:ng_words_for_stranger_mention, text, hit_word, options) if hit_word.present?
      hit_word.present?
    end

    def reject_with_custom_words?(text, custom_ng_words)
      custom_ng_words.any? { |word| include?(text, word) }
    end

    def hashtag_reject?(hashtag_count, **options)
      hit = post_hash_tags_max.positive? && post_hash_tags_max < hashtag_count
      record_count!(:hashtag_count, hashtag_count, options) if hit
      hit
    end

    def hashtag_reject_with_extractor?(text)
      hashtag_reject?(Extractor.extract_hashtags(text)&.size || 0)
    end

    def mention_reject?(mention_count, **options)
      hit = post_mentions_max.positive? && post_mentions_max < mention_count
      record_count!(:mention_count, mention_count, options) if hit
      hit
    end

    def mention_reject_with_extractor?(text)
      mention_reject?(text.gsub(Account::MENTION_RE)&.count || 0)
    end

    def stranger_mention_reject_with_count?(mention_count, **options)
      hit = post_stranger_mentions_max.positive? && post_stranger_mentions_max < mention_count
      record_count!(:stranger_mention_count, mention_count, options) if hit
      hit
    end

    def stranger_mention_reject_with_extractor?(text)
      stranger_mention_reject_with_count?(text.gsub(Account::MENTION_RE)&.count || 0)
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

    def post_mentions_max
      value = Setting.post_mentions_max
      value.is_a?(Integer) && value.positive? ? value : 0
    end

    def post_stranger_mentions_max
      value = Setting.post_stranger_mentions_max
      value.is_a?(Integer) && value.positive? ? value : 0
    end

    def record!(type, text, keyword, options)
      return unless options[:uri] && options[:target_type]
      return if options.key?(:public) && !options.delete(:public)

      return if NgwordHistory.where('created_at > ?', 1.day.ago).exists?(uri: options[:uri], keyword: keyword)

      NgwordHistory.create(options.merge({
        reason: type,
        text: text,
        keyword: keyword,
      }))
    end

    def record_count!(type, count, options)
      return unless options[:text] && options[:uri] && options[:target_type]
      return if options.key?(:public) && !options.delete(:public)

      return if NgwordHistory.where('created_at > ?', 1.day.ago).exists?(uri: options[:uri], reason: type)

      NgwordHistory.create(options.merge({
        reason: type,
        text: options[:text],
        keyword: '',
        count: count,
      }))
    end
  end
end
