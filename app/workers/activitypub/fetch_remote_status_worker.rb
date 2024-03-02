# frozen_string_literal: true

class ActivityPub::FetchRemoteStatusWorker
  include Sidekiq::Worker
  include Redisable

  sidekiq_options queue: 'pull', retry: 3

  def perform(uri, author_account_id, on_behalf_of_account_id)
    author       = Account.find(author_account_id)
    on_behalf_of = on_behalf_of_account_id.present? ? Account.find(on_behalf_of_account_id) : nil

    ActivityPub::FetchRemoteStatusService.new.call(uri, on_behalf_of: on_behalf_of, expected_actor_uri: ActivityPub::TagManager.instance.uri_for(author), request_id: uri)
  rescue ActiveRecord::RecordNotFound, Mastodon::RaceConditionError
    true
  end
end
