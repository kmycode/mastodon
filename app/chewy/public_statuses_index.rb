# frozen_string_literal: true

class PublicStatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  # ElasticSearch config is moved to "/config/elasticsearch.default.yml".
  # Edit it when original Mastodon changed ElasticSearch config.
  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: ChewyConfig.instance.public_statuses

  index_scope ::Status.unscoped
                      .kept
                      .indexable
                      .includes(:media_attachments, :preloadable_poll, :tags, :account, preview_cards_status: :preview_card)

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: ChewyConfig.instance.public_statuses_analyzers.dig('text', 'analyzer'), value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: ChewyConfig.instance.public_statuses_analyzers.dig('text', 'stemmed', 'analyzer')) }
    field(:tags, type: 'text', analyzer: ChewyConfig.instance.public_statuses_analyzers.dig('tags', 'analyzer'), value: ->(status) { status.tags.map(&:display_name) })
    field(:language, type: 'keyword')
    field(:domain, type: 'keyword', value: ->(status) { status.account.domain || '' })
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date', value: ->(status) { clamp_date(status.created_at) })
  end
end
