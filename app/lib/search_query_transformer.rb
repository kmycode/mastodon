# frozen_string_literal: true

class SearchQueryTransformer < Parslet::Transform
  SUPPORTED_PREFIXES = %w(
    has
    is
    my
    language
    from
    before
    after
    during
    in
    domain
    order
    searchability
  ).freeze

  class Query
    def initialize(clauses, options = {})
      raise ArgumentError if options[:current_account].nil?

      @clauses = clauses
      @options = options
      @searchability = options[:searchability]&.to_sym || :public

      flags_from_clauses!
    end

    def request
      search = Chewy::Search::Request.new(*indexes).filter(default_filter)

      must_clauses.each { |clause| search = search.query.must(clause.to_query) }
      must_not_clauses.each { |clause| search = search.query.must_not(clause.to_query) }
      filter_clauses.each { |clause| search = search.filter(**clause.to_query) }

      search
    end

    def order_by
      return @order_by if @order_by

      @order_by = 'desc'
      order_clauses.each { |clause| @order_by = clause.term }
      @order_by
    end

    def valid
      must_clauses.any? || must_not_clauses.any? || filter_clauses.any?
    end

    private

    def clauses_by_operator
      @clauses_by_operator ||= @clauses.compact.group_by(&:operator).to_h
    end

    def flags_from_clauses!
      @flags = clauses_by_operator.fetch(:flag, []).to_h { |clause| [clause.prefix, clause.term] }
    end

    def must_clauses
      clauses_by_operator.fetch(:must, [])
    end

    def must_not_clauses
      clauses_by_operator.fetch(:must_not, [])
    end

    def filter_clauses
      clauses_by_operator.fetch(:filter, [])
    end

    def order_clauses
      clauses_by_operator.fetch(:order, [])
    end

    def indexes
      case @flags['in']
      when 'library'
        [StatusesIndex]
      else
        @options[:current_account].user&.setting_use_public_index ? [PublicStatusesIndex, StatusesIndex] : [StatusesIndex]
      end
    end

    def default_filter
      definition_should = [
        public_index,
        searchability_limited,
      ]
      definition_should << searchability_public if %i(public public_unlisted).include?(@searchability)
      definition_should << searchability_private if %i(public public_unlisted unlisted private).include?(@searchability)
      definition_should << searchable_by_me if %i(public public_unlisted unlisted private direct).include?(@searchability)
      definition_should << self_posts if %i(public public_unlisted unlisted private direct).exclude?(@searchability)

      {
        bool: {
          should: definition_should,
          minimum_should_match: 1,
        },
      }
    end

    def public_index
      {
        term: {
          _index: PublicStatusesIndex.index_name,
        },
      }
    end

    def searchable_by_me
      {
        bool: {
          must: [
            {
              term: { _index: StatusesIndex.index_name },
            },
            {
              term: { searchable_by: @options[:current_account].id },
            },
          ],
          must_not: [
            {
              term: { searchability: 'limited' },
            },
          ],
        },
      }
    end

    def self_posts
      {
        bool: {
          must: [
            {
              term: { _index: StatusesIndex.index_name },
            },
            {
              term: { account_id: @options[:current_account].id },
            },
          ],
        },
      }
    end

    def searchability_public
      {
        bool: {
          must: [
            {
              term: { _index: StatusesIndex.index_name },
            },
            {
              term: { searchability: 'public' },
            },
          ],
        },
      }
    end

    def searchability_private
      {
        bool: {
          must: [
            {
              term: { _index: StatusesIndex.index_name },
            },
            {
              term: { searchability: 'private' },
            },
            {
              terms: { account_id: following_account_ids },
            },
          ],
        },
      }
    end

    def searchability_limited
      {
        bool: {
          must: [
            {
              term: { _index: StatusesIndex.index_name },
            },
            {
              term: { searchability: 'limited' },
            },
            {
              term: { account_id: @options[:current_account].id },
            },
          ],
        },
      }
    end

    def following_account_ids
      return @following_account_ids if defined?(@following_account_ids)

      account_exists_sql     = Account.where('accounts.id = follows.target_account_id').where(searchability: %w(public public_unlisted private)).reorder(nil).select(1).to_sql
      status_exists_sql      = Status.where('statuses.account_id = follows.target_account_id').where(reblog_of_id: nil).where(searchability: %w(public public_unlisted private)).reorder(nil).select(1).to_sql
      following_accounts     = Follow.where(account_id: @options[:current_account].id).merge(Account.where("EXISTS (#{account_exists_sql})").or(Account.where("EXISTS (#{status_exists_sql})")))
      @following_account_ids = following_accounts.pluck(:target_account_id)
    end
  end

  class Operator
    class << self
      def symbol(str)
        case str
        when '+', nil
          :must
        when '-'
          :must_not
        else
          raise "Unknown operator: #{str}"
        end
      end
    end
  end

  class TermClause
    attr_reader :operator, :term

    def initialize(operator, term)
      @operator = Operator.symbol(operator)
      @term = term
    end

    def to_query
      if @term.start_with?('#')
        { match: { tags: { query: @term, operator: 'and' } } }
      else
        # Memo for checking when manually merge
        # { multi_match: { type: 'most_fields', query: @term, fields: ['text', 'text.stemmed'], operator: 'and' } }
        { match_phrase: { text: { query: @term } } }
      end
    end
  end

  class PhraseClause
    attr_reader :operator, :phrase

    def initialize(operator, phrase)
      @operator = Operator.symbol(operator)
      @phrase = phrase
    end

    def to_query
      { match_phrase: { text: { query: @phrase } } }
    end
  end

  class PrefixClause
    attr_reader :operator, :prefix, :term

    def initialize(prefix, operator, term, options = {}) # rubocop:disable Metrics/CyclomaticComplexity
      @prefix = prefix
      @negated = operator == '-'
      @options = options
      @operator = :filter
      @statuses_index_only = false

      case prefix
      when 'has', 'is'
        @filter = :properties
        @type = :term
        @term = term
      when 'language'
        @filter = :language
        @type = :term
        @term = language_code_from_term(term)
      when 'from'
        @filter = :account_id
        @type = :term
        @term = account_id_from_term(term)
      when 'domain'
        @filter = :domain
        @type = :term
        @term = domain_from_term(term)
      when 'before'
        @filter = :created_at
        @type = :range
        @term = { lt: term, time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'after'
        @filter = :created_at
        @type = :range
        @term = { gt: term, time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'during'
        @filter = :created_at
        @type = :range
        @term = { gte: term, lte: term, time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'in'
        @operator = :flag
        @term = term
      when 'my'
        @type = :term
        @term = @options[:current_account]&.id
        @statuses_index_only = true
        case term
        when 'favourited', 'favorited', 'fav'
          @filter = :favourited_by
        when 'boosted', 'bt'
          @filter = :reblogged_by
        when 'replied', 'mentioned', 're'
          @filter = :mentioned_by
        when 'referenced', 'ref'
          @filter = :referenced_by
        when 'emoji_reacted', 'stamped', 'stamp'
          @filter = :emoji_reacted_by
        when 'bookmarked', 'bm'
          @filter = :bookmarked_by
        when 'categoried', 'bmc'
          @filter = :bookmark_categoried_by
        when 'voted', 'vote'
          @filter = :voted_by
        when 'interacted', 'act'
          @filter = :searchable_by
        else
          raise "Unknown prefix: my:#{term}"
        end
      when 'order'
        @operator = :order
        @term = case term
                when 'asc'
                  term
                else
                  'desc'
                end
      else
        raise "Unknown prefix: #{prefix}"
      end
    end

    def to_query
      if @negated
        { bool: { must_not: { @type => { @filter => @term } } } }
      else
        { @type => { @filter => @term } }
      end
    end

    private

    def account_id_from_term(term)
      return @options[:current_account]&.id || -1 if term == 'me'

      username, domain = term.gsub(/\A@/, '').split('@')
      domain = nil if TagManager.instance.local_domain?(domain)
      account = Account.find_remote(username, domain)

      # If the account is not found, we want to return empty results, so return
      # an ID that does not exist
      account&.id || -1
    end

    def domain_from_term(term)
      return '' if ['local', 'me', Rails.configuration.x.local_domain].include?(term)

      term
    end

    def language_code_from_term(term)
      language_code = term

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      language_code = term.downcase

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      language_code = term.split(/[_-]/).first.downcase

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      term
    end
  end

  rule(clause: subtree(:clause)) do
    prefix   = clause[:prefix][:term].to_s if clause[:prefix]
    operator = clause[:operator]&.to_s
    term     = clause[:phrase] ? clause[:phrase].map { |term| term[:term].to_s }.join(' ') : clause[:term].to_s

    if clause[:prefix] && SUPPORTED_PREFIXES.include?(prefix)
      PrefixClause.new(prefix, operator, term, current_account: current_account)
    elsif clause[:prefix]
      TermClause.new(operator, "#{prefix} #{term}")
    elsif clause[:term]
      TermClause.new(operator, term)
    elsif clause[:phrase]
      PhraseClause.new(operator, term)
    else
      raise "Unexpected clause type: #{clause}"
    end
  end

  rule(junk: subtree(:junk)) do
    nil
  end

  rule(query: sequence(:clauses)) do
    Query.new(clauses, current_account: current_account, searchability: searchability)
  end
end
