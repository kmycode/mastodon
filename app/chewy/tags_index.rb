# frozen_string_literal: true

class TagsIndex < Chewy::Index
  include DatetimeClampingConcern

  # ElasticSearch config is moved to "/config/elasticsearch.default.yml".
  # Edit it when original Mastodon changed ElasticSearch config.
  settings index: index_preset(refresh_interval: '30s'), analysis: ChewyConfig.instance.tags

  index_scope ::Tag.listable

  crutch :time_period do
    7.days.ago.to_date..0.days.ago.to_date
  end

  root date_detection: false do
    field(:name, type: 'text', analyzer: ChewyConfig.instance.tags_analyzers.dig('name', 'analyzer'), value: :display_name) do
      field(:edge_ngram, type: 'text', analyzer: ChewyConfig.instance.tags_analyzers.dig('name', 'edge_ngram', 'analyzer'), search_analyzer: ChewyConfig.instance.tags_analyzers.dig('name', 'edge_ngram', 'search_analyzer'))
    end
    field(:reviewed, type: 'boolean', value: ->(tag) { tag.reviewed? })
    field(:usage, type: 'long', value: ->(tag, crutches) { tag.history.aggregate(crutches.time_period).accounts })
    field(:last_status_at, type: 'date', value: ->(tag) { clamp_date(tag.last_status_at || tag.created_at) })
  end
end
