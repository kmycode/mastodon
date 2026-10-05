# frozen_string_literal: true

class TextPattern
  class << self
    def string_to_array(text)
      text.delete("\r").split("\n")
    end

    def detect_keyword(text, pattern_array, local: true)
      return nil if pattern_array.blank?
      return nil if text.blank?

      pattern_array = string_to_array(pattern_array) if pattern_array.is_a?(String)
      text = PlainTextFormatter.new(text, false).to_s unless local

      pattern_array.detect { |pattern| include?(text, pattern) ? pattern : nil }
    end

    def detect_keyword?(text, pattern_array, local: true)
      detect_keyword(text, pattern_array, local: local).present?
    end

    def include?(text, pattern)
      if pattern.start_with?('?') && pattern.size >= 2
        text =~ /#{pattern[1..]}/
      else
        text.include?(pattern)
      end
    end
  end
end
