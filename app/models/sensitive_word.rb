# frozen_string_literal: true

# == Schema Information
#
# Table name: sensitive_words
#
#  id         :bigint(8)        not null, primary key
#  keyword    :string           not null
#  regexp     :boolean          default(FALSE), not null
#  remote     :boolean          default(FALSE), not null
#  spoiler    :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class SensitiveWord < ApplicationRecord
  attr_accessor :keywords, :regexps, :remotes, :spoilers

  class << self
    def caches
      Rails.cache.fetch('sensitive_words') { SensitiveWord.where.not(id: 0).order(:keyword).to_a }
    end

    def save_from_hashes(rows)
      unmatched = caches
      matched = []

      SensitiveWord.transaction do
        rows.filter { |item| item[:keyword].present? }.each do |item|
          exists = unmatched.find { |i| i.keyword == item[:keyword] }

          if exists.present?
            unmatched.delete(exists)
            matched << exists

            next if exists.regexp == item[:regexp] && exists.remote == item[:remote] && exists.spoiler == item[:spoiler]

            exists.update!(regexp: item[:regexp], remote: item[:remote], spoiler: item[:spoiler])
          elsif matched.none? { |i| i.keyword == item[:keyword] }
            SensitiveWord.create!(
              keyword: item[:keyword],
              regexp: item[:regexp],
              remote: item[:remote],
              spoiler: item[:spoiler]
            )
          end
        end

        SensitiveWord.destroy(unmatched.map(&:id))
      end

      true
      # rescue
      # false
    end

    def save_from_raws(rows)
      regexps = rows['regexps'] || []
      remotes = rows['remotes'] || []
      spoilers = rows['spoilers'] || []

      hashes = (rows['keywords'] || []).zip(rows['temporary_ids'] || []).map do |item|
        temp_id = item[1]
        {
          keyword: item[0],
          regexp: regexps.include?(temp_id),
          remote: remotes.include?(temp_id),
          spoiler: spoilers.include?(temp_id),
        }
      end

      save_from_hashes(hashes)
    end
  end

  private

  def invalidate_cache!
    Rails.cache.delete('sensitive_words')
  end
end
