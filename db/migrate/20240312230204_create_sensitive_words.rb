# frozen_string_literal: true

class CreateSensitiveWords < ActiveRecord::Migration[7.1]
  class Setting < ApplicationRecord
    def value
      YAML.safe_load(self[:value], permitted_classes: [ActiveSupport::HashWithIndifferentAccess, Symbol]) if self[:value].present?
    end

    def value=(new_value)
      self[:value] = new_value.to_yaml
    end
  end

  class SensitiveWord < ApplicationRecord; end

  def normalized_keyword(keyword)
    if regexp?(keyword)
      keyword[1..]
    else
      keyword
    end
  end

  def regexp?(keyword)
    keyword.start_with?('?') && keyword.size >= 2
  end

  def up # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    create_table :sensitive_words do |t|
      t.string :keyword, null: false
      t.boolean :regexp, null: false, default: false
      t.boolean :remote, null: false, default: false
      t.boolean :spoiler, null: false, default: true

      t.timestamps
    end

    settings = Setting.where(var: %i(sensitive_words sensitive_words_for_full sensitive_words_all sensitive_words_all_for_full))
    sensitive_words = settings.find { |s| s.var == 'sensitive_words' }&.value&.compact_blank&.uniq || []
    sensitive_words_for_full = settings.find { |s| s.var == 'sensitive_words_for_full' }&.value&.compact_blank&.uniq || []
    sensitive_words_all = settings.find { |s| s.var == 'sensitive_words_all' }&.value&.compact_blank&.uniq || []
    sensitive_words_all_for_full = settings.find { |s| s.var == 'sensitive_words_all_for_full' }&.value&.compact_blank&.uniq || []

    sensitive_words_all_for_full.each { |s| SensitiveWord.create!(keyword: normalized_keyword(s), regexp: regexp?(s), remote: true, spoiler: true) }
    sensitive_words_for_full.reject { |w| sensitive_words_all_for_full.include?(w) }.each { |s| SensitiveWord.create!(keyword: normalized_keyword(s), regexp: regexp?(s), remote: false, spoiler: true) }
    sensitive_words_all.reject { |w| (sensitive_words_all_for_full + sensitive_words_for_full).include?(w) }.each { |s| SensitiveWord.create!(keyword: normalized_keyword(s), regexp: regexp?(s), remote: true, spoiler: false) }
    sensitive_words.reject { |w| (sensitive_words_all_for_full + sensitive_words_for_full + sensitive_words_all).include?(w) }.each { |s| SensitiveWord.create!(keyword: normalized_keyword(s), regexp: regexp?(s), remote: false, spoiler: false) }

    settings.destroy_all
  end

  def down
    sensitive_words = SensitiveWord.where(remote: false, spoiler: false).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }
    sensitive_words_for_full = SensitiveWord.where(remote: false, spoiler: true).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }
    sensitive_words_all = SensitiveWord.where(remote: true, spoiler: false).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }
    sensitive_words_all_for_full = SensitiveWord.where(remote: true, spoiler: true).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }

    Setting.where(var: %i(sensitive_words sensitive_words_for_full sensitive_words_all sensitive_words_all_for_full)).destroy_all

    Setting.new(var: :sensitive_words).tap { |s| s.value = sensitive_words }.save!
    Setting.new(var: :sensitive_words_for_full).tap { |s| s.value = sensitive_words_for_full }.save!
    Setting.new(var: :sensitive_words_all).tap { |s| s.value = sensitive_words_all }.save!
    Setting.new(var: :sensitive_words_all_for_full).tap { |s| s.value = sensitive_words_all_for_full }.save!

    drop_table :sensitive_words
  end
end
