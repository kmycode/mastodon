# frozen_string_literal: true

class SearchabilityUpdateService < BaseService
  def call(account)
    statuses = account.statuses.unset_searchability

    return unless statuses.exists?

    ids = statuses.pluck(:id)

    if account.public_searchability?
      statuses.update_all('searchability = CASE visibility WHEN 0 THEN 0 WHEN 10 THEN 0 WHEN 1 THEN 2 WHEN 2 THEN 2 ELSE 3 END, updated_at = CURRENT_TIMESTAMP')
    elsif account.unlisted_searchability?
      statuses.update_all('searchability = CASE visibility WHEN 0 THEN 1 WHEN 10 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 2 ELSE 3 END, updated_at = CURRENT_TIMESTAMP')
    elsif account.private_searchability?
      statuses.update_all('searchability = CASE WHEN visibility IN (0, 1, 2, 10) THEN 2 ELSE 3 END, updated_at = CURRENT_TIMESTAMP')
    else
      statuses.update_all('searchability = 3, updated_at = CURRENT_TIMESTAMP')
    end

    return unless Chewy.enabled?

    ids.each_slice(100) do |chunk_ids|
      StatusesIndex.import chunk_ids, update_fields: [:searchability]
    end
  end
end
