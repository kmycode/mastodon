# frozen_string_literal: true

# == Schema Information
#
# Table name: sensitive_words
#
#  id         :bigint(8)        not null, primary key
#  keyword    :string           not null
#  regexp     :boolean          default(FALSE), not null
#  remote     :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class SensitiveWord < ApplicationRecord
  attr_accessor :keywords, :regexps, :remotes

  before_save :prepare_cache_invalidation!
  before_destroy :prepare_cache_invalidation!
  after_commit :invalidate_cache!

  class << self
    def caches
      Rails.cache.fetch('sensitive_words') { SensitiveWord.where.not(id: 0).to_a }
    end

    def save_from_hashes(_rows)
      true
    end

    def save_from_raws(rows)
      hashes = rows['keywords'].zip(rows['regexps'], rows['remotes']).map do |item|
        {
          keyword: item[0],
          regexp: item[1] != '0',
          remote: item[2] != '0',
        }
      end

      save_from_hashes(hashes)
    end
  end

  private

  def prepare_cache_invalidation!
    @should_invalidate_cache = true
  end

  def invalidate_cache!
    return unless @should_invalidate_cache

    @should_invalidate_cache = false

    Rails.cache.delete('sensitive_words')
  end
end
