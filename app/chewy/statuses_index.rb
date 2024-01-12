# frozen_string_literal: true

class StatusesIndex < Chewy::Index
  include DatetimeClampingConcern

  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: {
    filter: {
      english_stop: {
        type: 'stop',
        stopwords: '_english_',
      },

      english_stemmer: {
        type: 'stemmer',
        language: 'english',
      },

      english_possessive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english',
      },

      my_posfilter: {
        type: 'sudachi_part_of_speech',
        stoptags: [
          '助詞',
          '助動詞',
          '補助記号,句点',
          '補助記号,読点',
        ],
      },
    },
    analyzer: {
      verbatim: {
        tokenizer: 'uax_url_email',
        filter: %w(lowercase),
      },

      content: {
        tokenizer: 'uax_url_email',
        filter: %w(
          english_possessive_stemmer
          lowercase
          asciifolding
          cjk_width
          english_stop
          english_stemmer
        ),
      },

      hashtag: {
        tokenizer: 'keyword',
        filter: %w(
          word_delimiter_graph
          lowercase
          asciifolding
          cjk_width
        ),
      },

      sudachi_analyzer: {
        tokenizer: 'sudachi_tokenizer',
        type: 'custom',
        filter: %w(
          english_possessive_stemmer
          lowercase
          asciifolding
          cjk_width
          english_stop
          english_stemmer
          my_posfilter
          sudachi_normalizedform
        ),
      },
    },
    tokenizer: {
      sudachi_tokenizer: {
        resources_path: '/etc/elasticsearch/sudachi',
        split_mode: 'A',
        type: 'sudachi_tokenizer',
        discard_punctuation: 'true',
      },
    },
  }

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
    field(:text, type: 'text', analyzer: 'sudachi_analyzer', value: ->(status) { status.searchable_text }) { field(:stemmed, type: 'text', analyzer: 'content') }
    field(:tags, type: 'text', analyzer: 'hashtag', value: ->(status) { status.tags.map(&:display_name) })
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
