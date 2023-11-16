# frozen_string_literal: true

class PublicStatusesIndex < Chewy::Index
  DEVELOPMENT_SETTINGS = {
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
    },

    analyzer: {
      verbatim: {
        tokenizer: 'uax_url_email',
        filter: %w(lowercase),
      },

      content: {
        tokenizer: 'standard',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
          english_stop
          english_stemmer
        ),
      },

      sudachi_analyzer: {
        tokenizer: 'standard',
        filter: %w(
          lowercase
          asciifolding
          cjk_width
          elision
          english_possessive_stemmer
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
    },
  }.freeze

  PRODUCTION_SETTINGS = {
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
  }.freeze

  settings index: index_preset(refresh_interval: '30s', number_of_shards: 5), analysis: Rails.env.test? ? DEVELOPMENT_SETTINGS : PRODUCTION_SETTINGS

  index_scope ::Status.unscoped
                      .kept
                      .indexable
                      .includes(:media_attachments, :preloadable_poll, :tags, :account, preview_cards_status: :preview_card)

  root date_detection: false do
    field(:id, type: 'long')
    field(:account_id, type: 'long')
    field(:text, type: 'text', analyzer: 'sudachi_analyzer', value: ->(status) { status.searchable_text })
    field(:tags, type: 'text', analyzer: 'hashtag', value: ->(status) { status.tags.map(&:display_name) })
    field(:language, type: 'keyword')
    field(:domain, type: 'keyword', value: ->(status) { status.account.domain || '' })
    field(:properties, type: 'keyword', value: ->(status) { status.searchable_properties })
    field(:created_at, type: 'date')
  end
end
