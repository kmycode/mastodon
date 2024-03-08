# frozen_string_literal: true

class AccountsIndex < Chewy::Index
  include DatetimeClampingConcern

  # ElasticSearch config is moved to "/config/elasticsearch.default.yml".
  # Edit it when original Mastodon changed ElasticSearch config.
  settings index: index_preset(refresh_interval: '30s'), analysis: ChewyConfig.instance.accounts

  index_scope ::Account.searchable.includes(:account_stat)

  root date_detection: false do
    field(:id, type: 'long')
    field(:following_count, type: 'long', value: ->(account) { account.public_following_count })
    field(:followers_count, type: 'long', value: ->(account) { account.public_followers_count })
    field(:properties, type: 'keyword', value: ->(account) { account.searchable_properties })
    field(:last_status_at, type: 'date', value: ->(account) { clamp_date(account.last_status_at || account.created_at) })
    field(:domain, type: 'keyword', value: ->(account) { account.domain || '' })
    field(:display_name, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('display_name', 'analyzer')) do
      field :edge_ngram, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('display_name', 'edge_ngram', 'analyzer'), search_analyzer: ChewyConfig.instance.accounts_analyzers.dig('display_name', 'edge_ngram', 'search_analyzer')
    end
    field(:username, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('username', 'analyzer'), value: lambda { |account|
                                                                                                                           [account.username, account.domain].compact.join('@')
                                                                                                                         }) do
      field :edge_ngram, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('username', 'edge_ngram', 'analyzer'),
                         search_analyzer: ChewyConfig.instance.accounts_analyzers.dig('username', 'edge_ngram', 'search_analyzer')
    end
    field(:text, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('text', 'analyzer'), value: ->(account) { account.searchable_text }) { field(:stemmed, type: 'text', analyzer: ChewyConfig.instance.accounts_analyzers.dig('text', 'stemmed', 'analyzer')) }
  end
end
