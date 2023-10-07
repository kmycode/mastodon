# frozen_string_literal: true

class DeliveryAntennaService
  include FormattingHelper
  include DtlHelper

  def call(status, update, **options)
    @status = status
    @account = @status.account
    @update = update

    mode = options[:mode] || :home
    case mode
    when :home
      delivery!
    when :stl
      delivery_stl!
    when :ltl
      delivery_ltl!
    end
  end

  private

  def delivery!
    must_dtl_tag = @account.dissubscribable
    return if must_dtl_tag && !DTL_ENABLED

    tag_ids = @status.tags.pluck(:id)
    domain = @account.domain || Rails.configuration.x.local_domain
    follower_ids = @status.unlisted_visibility? ? @status.account.followers.pluck(:id) : []

    antennas = Antenna.availables
    antennas = antennas.left_joins(:antenna_domains).where(any_domains: true).or(Antenna.left_joins(:antenna_domains).where(antenna_domains: { name: domain }))

    antennas = Antenna.where(id: antennas.select(:id))
    antennas = antennas.left_joins(:antenna_accounts).where(any_accounts: true).or(Antenna.left_joins(:antenna_accounts).where(antenna_accounts: { account: @account }))

    antennas = Antenna.where(id: antennas.select(:id))
    if must_dtl_tag
      dtl_tag = Tag.find_or_create_by_names(DTL_TAG).first
      return if !dtl_tag || tag_ids.exclude?(dtl_tag.id)

      antennas = antennas.left_joins(:antenna_tags).where(antenna_tags: { tag_id: dtl_tag.id })
    else
      antennas = antennas.left_joins(:antenna_tags).where(any_tags: true).or(Antenna.left_joins(:antenna_tags).where(antenna_tags: { tag_id: tag_ids }))
    end

    antennas = antennas.where(account_id: Account.without_suspended.joins(:user).select('accounts.id').where('users.current_sign_in_at > ?', User::ACTIVE_DURATION.ago))
    antennas = antennas.where(account: @status.account.followers) if followers_only?
    antennas = antennas.where(account: @status.mentioned_accounts) if mentioned_users_only?
    antennas = antennas.where(with_media_only: false) unless @status.with_media?
    antennas = antennas.where(ignore_reblog: false) if @status.reblog?
    antennas = antennas.where(stl: false, ltl: false)

    collection = AntennaCollection.new(@status, @update, false)
    content = extract_status_plain_text_with_spoiler_text(@status)

    antennas.in_batches do |ans|
      ans.each do |antenna|
        next unless antenna.enabled?
        next if antenna.keywords&.any? && antenna.keywords&.none? { |keyword| content.include?(keyword) }
        next if antenna.exclude_keywords&.any? { |keyword| content.include?(keyword) }
        next if antenna.exclude_accounts&.include?(@status.account_id)
        next if antenna.exclude_domains&.include?(domain)
        next if antenna.exclude_tags&.any? { |tag_id| tag_ids.include?(tag_id) }

        searchability = @status.compute_searchability
        next if @status.unlisted_visibility? && searchability != 'public' && follower_ids.exclude?(antenna.account_id)
        next if @status.unlisted_visibility? && searchability == 'public' && follower_ids.exclude?(antenna.account_id) && antenna.any_keywords && antenna.any_tags

        collection.push(antenna)
      end
    end

    collection.deliver!
  end

  def delivery_stl!
    antennas = Antenna.available_stls
    antennas = antennas.where(account_id: Account.without_suspended.joins(:user).select('accounts.id').where('users.current_sign_in_at > ?', User::ACTIVE_DURATION.ago))

    home_post = !@account.domain.nil? || @status.reblog? || [:public, :public_unlisted, :login].exclude?(@status.visibility.to_sym)
    antennas = antennas.where(account: @account.followers).or(antennas.where(account: @account)).where('insert_feeds IS FALSE OR list_id > 0') if home_post && !@status.limited_visibility?
    antennas = antennas.where(account: @status.mentioned_accounts).or(antennas.where(account: @account)).where('insert_feeds IS FALSE OR list_id > 0') if @status.limited_visibility?

    collection = AntennaCollection.new(@status, @update, home_post)

    antennas.in_batches do |ans|
      ans.each do |antenna|
        next if antenna.expired?

        collection.push(antenna)
      end
    end

    collection.deliver!
  end

  def delivery_ltl!
    return if %i(public public_unlisted login).exclude?(@status.visibility.to_sym)
    return unless @account.local?
    return if @status.reblog?

    antennas = Antenna.available_ltls
    antennas = antennas.where(account_id: Account.without_suspended.joins(:user).select('accounts.id').where('users.current_sign_in_at > ?', User::ACTIVE_DURATION.ago))

    collection = AntennaCollection.new(@status, @update, false)

    antennas.in_batches do |ans|
      ans.each do |antenna|
        next if antenna.expired?

        collection.push(antenna)
      end
    end

    collection.deliver!
  end

  def followers_only?
    case @status.visibility.to_sym
    when :public, :public_unlisted, :login, :limited
      false
    when :unlisted
      @status.compute_searchability != 'public'
    else
      true
    end
  end

  def mentioned_users_only?
    @status.visibility.to_sym == :limited
  end

  class AntennaCollection
    def initialize(status, update, stl_home = false) # rubocop:disable Style/OptionalBooleanParameter
      @status = status
      @update = update
      @stl_home = stl_home
      @home_account_ids = []
      @list_ids = []
      @antenna_timeline_ids = []
    end

    def push(antenna)
      if !antenna.insert_feeds?
        @antenna_timeline_ids << { id: antenna.id, antenna_id: antenna.id }
      elsif antenna.list_id.zero?
        @home_account_ids << { id: antenna.account_id, antenna_id: antenna.id } if @home_account_ids.none? { |id| id[:id] == antenna.account_id }
      elsif @list_ids.none? { |id| id[:id] == antenna.list_id }
        @list_ids << { id: antenna.list_id, antenna_id: antenna.id }
      end
    end

    def deliver!
      lists = @list_ids
      homes = @home_account_ids
      timelines = @antenna_timeline_ids

      if lists.any?
        FeedInsertWorker.push_bulk(lists) do |list|
          [@status.id, list[:id], 'list', { 'update' => @update, 'stl_home' => @stl_home || false, 'antenna_id' => list[:antenna_id] }]
        end
      end

      if homes.any?
        FeedInsertWorker.push_bulk(homes) do |home|
          [@status.id, home[:id], 'home', { 'update' => @update, 'antenna_id' => home[:antenna_id] }]
        end
      end

      return unless timelines.any?

      FeedInsertWorker.push_bulk(timelines) do |antenna|
        [@status.id, antenna[:id], 'antenna', { 'update' => @update }]
      end
    end
  end
end
