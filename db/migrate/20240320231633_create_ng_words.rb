# frozen_string_literal: true

class CreateNgWords < ActiveRecord::Migration[7.1]
  class Setting < ApplicationRecord
    def value
      YAML.safe_load(self[:value], permitted_classes: [ActiveSupport::HashWithIndifferentAccess, Symbol]) if self[:value].present?
    end

    def value=(new_value)
      self[:value] = new_value.to_yaml
    end
  end

  class NgWord < ApplicationRecord; end

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

  def up
    create_table :ng_words do |t|
      t.string :keyword, null: false
      t.boolean :regexp, null: false, default: false
      t.boolean :stranger, null: false, default: true

      t.timestamps
    end

    settings = Setting.where(var: %i(ng_words ng_words_for_stranger_mention))
    ng_words = settings.find { |s| s.var == 'ng_words' }&.value&.compact_blank&.uniq || []
    ng_words_for_stranger_mention = settings.find { |s| s.var == 'ng_words_for_stranger_mention' }&.value&.compact_blank&.uniq || []

    (ng_words + ng_words_for_stranger_mention).compact.uniq.each do |word|
      NgWord.create!(
        keyword: normalized_keyword(word),
        regexp: regexp?(word),
        stranger: ng_words_for_stranger_mention.include?(word)
      )
    end

    settings.destroy_all
  end

  def down
    ng_words = NgWord.where(stranger: false).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }
    ng_words_for_stranger_mention = NgWord.where(stranger: true).map { |s| s.regexp ? "?#{s.keyword}" : s.keyword }

    Setting.where(var: %i(ng_words ng_words_for_stranger_mention)).destroy_all

    Setting.new(var: :ng_words).tap { |s| s.value = ng_words }.save!
    Setting.new(var: :ng_words_for_stranger_mention).tap { |s| s.value = ng_words_for_stranger_mention }.save!

    drop_table :ng_words
  end
end
