# frozen_string_literal: true

# == Schema Information
#
# Table name: specified_domains
#
#  id         :bigint(8)        not null, primary key
#  domain     :string           not null
#  table      :integer          default(0), not null
#  options    :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class SpecifiedDomain < ApplicationRecord
  attr_accessor :domains

  validates :domain, uniqueness: { scope: :table }
  after_commit :invalidate_cache!

  scope :white_list_domains, -> { where(table: 0) }

  class << self
    def white_list_domain_caches
      Rails.cache.fetch('specified_domains:white_list') { white_list_domains.order(:domain).to_a }
    end

    def save_from_hashes(rows, type, caches)
      unmatched = caches
      matched = []

      SpecifiedDomain.transaction do
        rows.filter { |item| item[:domain].present? }.each do |item|
          exists = unmatched.find { |i| i.domain == item[:domain] }

          if exists.present?
            unmatched.delete(exists)
            matched << exists

            next unless item.key?(:options) && item[:options] == exists.options

            exists.update!(options: item[:options])
          elsif matched.none? { |i| i.domain == item[:domain] }
            SpecifiedDomain.create!(
              domain: item[:domain],
              table: type,
              options: item[:options] || {}
            )
          end
        end

        SpecifiedDomain.destroy(unmatched.map(&:id))
      end

      true
    end

    def save_from_raws(rows, type, caches)
      hashes = (rows['domains'] || []).map do |domain|
        {
          domain: domain,
          type: type,
        }
      end

      save_from_hashes(hashes, type, caches)
    end

    def save_from_raws_as_white_list(rows)
      save_from_raws(rows, 0, white_list_domain_caches)
    end
  end

  private

  def invalidate_cache!
    Rails.cache.delete('specified_domains:white_list')
  end
end
