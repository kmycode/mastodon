# frozen_string_literal: true

class StatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  # ElasticSearch config is moved to "/config/elasticsearch.default.yml".
  # Edit it when original Mastodon changed ElasticSearch config.
  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: ChewyConfig.instance.statuses

  index_scope ::Status.unscoped.kept.without_reblogs.includes(
    :account,
    :media_attachments,
    :local_mentioned,
    :local_favorited,
    :local_reblogged,
    :local_bookmarked,
    :local_emoji_reacted,
    :tags,
    :local_referenced,
    preview_cards_status: :preview_card,
    preloadable_poll: :local_voters
  ),
              delete_if: lambda { |status|
                           if status.searchability == 'direct'
                             status.searchable_by.empty?
                           else
                             status.searchability == 'limited' ? !status.local? : false
                           end
                         }

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: ChewyConfig.instance.statuses_analyzers.dig('text', 'analyzer'), value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: ChewyConfig.instance.statuses_analyzers.dig('text', 'stemmed', 'analyzer')) }
    field(:tags, type: 'text', analyzer: ChewyConfig.instance.statuses_analyzers.dig('tags', 'analyzer'), value: ->(status) { status.tags.map(&:display_name) })
    field(:searchable_by, type: 'long', value: ->(status) { status.searchable_by })
    field(:mentioned_by, type: 'long', value: ->(status) { status.mentioned_by })
    field(:favourited_by, type: 'long', value: ->(status) { status.favourited_by })
    field(:reblogged_by, type: 'long', value: ->(status) { status.reblogged_by })
    field(:bookmarked_by, type: 'long', value: ->(status) { status.bookmarked_by })
    field(:bookmark_categoried_by, type: 'long', value: ->(status) { status.bookmark_categoried_by })
    field(:emoji_reacted_by, type: 'long', value: ->(status) { status.emoji_reacted_by })
    field(:referenced_by, type: 'long', value: ->(status) { status.referenced_by })
    field(:voted_by, type: 'long', value: ->(status) { status.voted_by })
    field(:searchability, type: 'keyword', value: ->(status) { status.compute_searchability })
    field(:visibility, type: 'keyword', value: ->(status) { status.searchable_visibility })
    field(:language, type: 'keyword')
    field(:domain, type: 'keyword', value: ->(status) { status.account.domain || '' })
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date', value: ->(status) { clamp_date(status.created_at) })
  end
end
