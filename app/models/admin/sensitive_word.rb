# frozen_string_literal: true

class Admin::SensitiveWord
  class << self
    def sensitive?(text, spoiler_text, local: true)
      exposure_text = spoiler_text.presence || text

      sensitive_words = ::SensitiveWord.caches
      sensitive_words.select!(&:remote) unless local

      return sensitive_words.filter(&:spoiler).any? { |word| include?(spoiler_text, word) } if spoiler_text.present?

      sensitive_words.any? { |word| include?(exposure_text, word) }
    end

    def modified_text(text, spoiler_text)
      spoiler_text.present? ? "#{spoiler_text}\n\n#{text}" : text
    end

    def alternative_text
      Setting.auto_warning_text.presence || I18n.t('admin.sensitive_words.alert') || 'CW'
    end

    private

    def include?(text, word)
      if word.regexp
        text =~ /#{word.keyword}/
      else
        text.include?(word.keyword)
      end
    end
  end
end
