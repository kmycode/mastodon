# frozen_string_literal: true

# == Schema Information
#
# Table name: ng_words
#
#  id         :bigint(8)        not null, primary key
#  keyword    :string           not null
#  regexp     :boolean          default(FALSE), not null
#  stranger   :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class NgWord < ApplicationRecord
  attr_accessor :keywords, :regexps, :strangers

  validate :check_regexp
  after_commit :invalidate_cache!

  class << self
    def caches
      Rails.cache.fetch('ng_words') { NgWord.where.not(id: 0).order(:keyword).to_a }
    end

    def save_from_hashes(rows)
      unmatched = caches
      matched = []

      NgWord.transaction do
        rows.filter { |item| item[:keyword].present? }.each do |item|
          exists = unmatched.find { |i| i.keyword == item[:keyword] }

          if exists.present?
            unmatched.delete(exists)
            matched << exists

            next if exists.regexp == item[:regexp] && exists.stranger == item[:stranger]

            exists.update!(regexp: item[:regexp], stranger: item[:stranger])
          elsif matched.none? { |i| i.keyword == item[:keyword] }
            NgWord.create!(
              keyword: item[:keyword],
              regexp: item[:regexp],
              stranger: item[:stranger]
            )
          end
        end

        NgWord.destroy(unmatched.map(&:id))
      end

      true
    end

    def save_from_raws(rows)
      regexps = rows['regexps'] || []
      strangers = rows['strangers'] || []

      hashes = (rows['keywords'] || []).zip(rows['temporary_ids'] || []).map do |item|
        temp_id = item[1]
        {
          keyword: item[0],
          regexp: regexps.include?(temp_id),
          stranger: strangers.include?(temp_id),
        }
      end

      save_from_hashes(hashes)
    end
  end

  private

  def invalidate_cache!
    Rails.cache.delete('ng_words')
  end

  def check_regexp
    return if keyword.blank? || !regexp

    begin
      Admin::NgWord.reject_with_custom_word?('Sample text', keyword)
    rescue
      raise Mastodon::ValidationError, I18n.t('admin.ng_words.test_error')
    end
  end
end
