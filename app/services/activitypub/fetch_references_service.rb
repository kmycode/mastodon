# frozen_string_literal: true

class ActivityPub::FetchReferencesService < BaseService
  include JsonLdHelper

  def call(account, collection_or_uri)
    @account = account

    collection_items(collection_or_uri)&.take(8)&.map { |item| value_or_id(item) }
  end

  private

  def collection_items(collection_or_uri)
    collection = fetch_collection(collection_or_uri)
    return unless collection.is_a?(Hash)

    collection = fetch_collection(collection['first']) if collection['first'].present?
    return unless collection.is_a?(Hash)

    case collection['type']
    when 'Collection', 'CollectionPage'
      as_array(collection['items'])
    when 'OrderedCollection', 'OrderedCollectionPage'
      as_array(collection['orderedItems'])
    end
  end

  def fetch_collection(collection_or_uri)
    return collection_or_uri if collection_or_uri.is_a?(Hash)
    return if unsupported_uri_scheme?(collection_or_uri)
    return if ActivityPub::TagManager.instance.local_uri?(collection_or_uri)

    # NOTE: For backward compatibility reasons, Mastodon signs outgoing
    # queries incorrectly by default.
    #
    # While this is relevant for all URLs with query strings, this is
    # the only code path where this happens in practice.
    #
    # Therefore, retry with correct signatures if this fails.
    begin
      fetch_resource_without_id_validation(collection_or_uri, nil, true)
    rescue Mastodon::UnexpectedResponseError => e
      raise unless e.response && e.response.code == 401 && Addressable::URI.parse(collection_or_uri).query.present?

      fetch_resource_without_id_validation(collection_or_uri, nil, true, request_options: { with_query_string: true })
    end
  end
end
