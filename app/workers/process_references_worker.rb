# frozen_string_literal: true

class ProcessReferencesWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 3

  def perform(status_id, ids, urls, no_fetch_urls = nil, quote_urls = nil)
    ProcessReferencesService.new.call(Status.find(status_id), ids || [], urls: urls || [], no_fetch_urls: no_fetch_urls, quote_urls: quote_urls || [])
  rescue ActiveRecord::RecordNotFound
    true
  end
end
