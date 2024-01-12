# frozen_string_literal: true

class AccountsIndex < Chewy::Index
  include DatetimeClampingConcern

  settings index: index_preset(refresh_interval: '30s'), analysis: {
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
      natural: {
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
        filter: %w(
          my_posfilter
          sudachi_normalizedform
        ),
        type: 'custom',
        tokenizer: 'sudachi_tokenizer',
      },

      verbatim: {
        tokenizer: 'standard',
        filter: %w(lowercase asciifolding cjk_width),
      },

      edge_ngram: {
        tokenizer: 'edge_ngram',
        filter: %w(lowercase asciifolding cjk_width),
      },
    },

    tokenizer: {
      edge_ngram: {
        type: 'edge_ngram',
        min_gram: 1,
        max_gram: 15,
      },

      sudachi_tokenizer: {
        resources_path: '/etc/elasticsearch/sudachi',
        split_mode: 'A',
        type: 'sudachi_tokenizer',
        discard_punctuation: 'true',
      },
    },
  }

  index_scope ::Account.searchable.includes(:account_stat)

  root date_detection: false do
    field(:id, type: 'long')
    field(:following_count, type: 'long', value: ->(account) { account.public_following_count })
    field(:followers_count, type: 'long', value: ->(account) { account.public_followers_count })
    field(:properties, type: 'keyword', value: ->(account) { account.searchable_properties })
    field(:last_status_at, type: 'date', value: ->(account) { clamp_date(account.last_status_at || account.created_at) })
    field(:domain, type: 'keyword', value: ->(account) { account.domain || '' })
    field(:display_name, type: 'text', analyzer: 'verbatim') { field :edge_ngram, type: 'text', analyzer: 'edge_ngram', search_analyzer: 'verbatim' }
    field(:username, type: 'text', analyzer: 'verbatim', value: ->(account) { [account.username, account.domain].compact.join('@') }) { field :edge_ngram, type: 'text', analyzer: 'edge_ngram', search_analyzer: 'verbatim' }
    field(:text, type: 'text', analyzer: 'sudachi_analyzer', value: ->(account) { account.searchable_text }) { field(:stemmed, type: 'text', analyzer: 'natural') }
  end
end
