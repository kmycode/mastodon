# frozen_string_literal: true

class StatusRelationshipsPresenter
  PINNABLE_VISIBILITIES = %w(public public_unlisted unlisted login private).freeze

  attr_reader :reblogs_map, :favourites_map, :mutes_map, :pins_map, :blocks_map, :domain_blocks_map,
              :bookmarks_map, :filters_map, :attributes_map, :emoji_reaction_allows_map, :emoji_reaction_availables_map

  def initialize(statuses, current_account_id = nil, **options)
    @current_account_id = current_account_id

    if current_account_id.nil?
      @reblogs_map         = {}
      @favourites_map      = {}
      @bookmarks_map       = {}
      @mutes_map           = {}
      @blocks_map          = {}
      @domain_blocks_map   = {}
      @pins_map            = {}
      @filters_map         = {}
      @emoji_reaction_allows_map = nil
    else
      statuses = statuses.compact
      statuses += statuses.filter_map(&:quote)
      status_ids          = statuses.flat_map { |s| [s.id, s.reblog_of_id] }.uniq.compact
      conversation_ids    = statuses.filter_map(&:conversation_id).uniq
      pinnable_status_ids = statuses.map(&:proper).filter_map { |s| s.id if s.account_id == current_account_id && PINNABLE_VISIBILITIES.include?(s.visibility) }

      @filters_map       = build_filters_map(statuses, current_account_id).merge(options[:filters_map] || {})
      @reblogs_map       = Status.reblogs_map(status_ids, current_account_id).merge(options[:reblogs_map] || {})
      @favourites_map    = Status.favourites_map(status_ids, current_account_id).merge(options[:favourites_map] || {})
      @bookmarks_map     = Status.bookmarks_map(status_ids, current_account_id).merge(options[:bookmarks_map] || {})
      @mutes_map         = Status.mutes_map(conversation_ids, current_account_id).merge(options[:mutes_map] || {})
      @blocks_map        = Status.blocks_map(statuses.map(&:account_id), current_account_id).merge(options[:blocks_map] || {})
      @domain_blocks_map = Status.domain_blocks_map(statuses.filter_map { |status| status.account.domain }.uniq, current_account_id).merge(options[:domain_blocks_map] || {})
      @pins_map          = Status.pins_map(pinnable_status_ids, current_account_id).merge(options[:pins_map] || {})
      @emoji_reaction_allows_map = Status.emoji_reaction_allows_map(status_ids, current_account_id).merge(options[:emoji_reaction_allows_map] || {})
      @attributes_map = options[:attributes_map] || {}
    end
  end

  private

  def build_filters_map(statuses, current_account_id)
    active_filters = CustomFilter.cached_filters_for(current_account_id)

    @filters_map = statuses.each_with_object({}) do |status, h|
      filter_matches = CustomFilter.apply_cached_filters(active_filters, status, following: following?(status.account_id))

      unless filter_matches.empty?
        h[status.id] = filter_matches
        h[status.reblog_of_id] = filter_matches if status.reblog?
      end
    end
  end

  def following?(other_account_id)
    return false if @current_account_id.nil?

    @account ||= Account.find(@current_account_id)
    return false unless @account

    @following_map ||= @account.following.pluck(:id)
    @following_map.include?(other_account_id)
  end
end
