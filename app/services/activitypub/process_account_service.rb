# frozen_string_literal: true

class ActivityPub::ProcessAccountService < BaseService
  include JsonLdHelper
  include DomainControlHelper
  include Redisable
  include Lockable

  SUBDOMAINS_RATELIMIT = 10
  DISCOVERIES_PER_REQUEST = 400
  SCAN_SEARCHABILITY_RE = /\[searchability:(public|followers|reactors|private)\]/
  SCAN_SEARCHABILITY_FEDIBIRD_RE = /searchable_by_(all_users|followers_only|reacted_users_only|nobody)/

  # Should be called with confirmed valid JSON
  # and WebFinger-resolved username and domain
  def call(username, domain, json, options = {})
    return if json['inbox'].blank? || unsupported_uri_scheme?(json['id']) || domain_not_allowed?(domain)

    @options     = options
    @json        = json
    @uri         = @json['id']
    @username    = username
    @domain      = TagManager.instance.normalize_domain(domain)
    @collections = {}

    return unless valid_account?

    # The key does not need to be unguessable, it just needs to be somewhat unique
    @options[:request_id] ||= "#{Time.now.utc.to_i}-#{username}@#{domain}"

    with_redis_lock("process_account:#{@uri}") do
      @account            = Account.remote.find_by(uri: @uri) if @options[:only_key]
      @account          ||= Account.find_remote(@username, @domain)
      @old_public_key     = @account&.public_key
      @old_protocol       = @account&.protocol
      @old_searchability  = @account&.searchability
      @suspension_changed = false

      if @account.nil?
        with_redis do |redis|
          return nil if redis.pfcount("unique_subdomains_for:#{PublicSuffix.domain(@domain, ignore_private: true)}") >= SUBDOMAINS_RATELIMIT

          discoveries = redis.incr("discovery_per_request:#{@options[:request_id]}")
          redis.expire("discovery_per_request:#{@options[:request_id]}", 5.minutes.seconds)
          return nil if discoveries > DISCOVERIES_PER_REQUEST
        end

        create_account
        fetch_instance_info
      end

      update_account
      process_tags

      process_duplicate_accounts! if @options[:verified_webfinger]
    end

    after_protocol_change! if protocol_changed?
    after_key_change! if key_changed? && !@options[:signed_with_known_key]
    clear_tombstones! if key_changed?
    after_suspension_change! if suspension_changed?

    unless @options[:only_key] || @account.suspended?
      check_featured_collection! if @account.featured_collection_url.present?
      check_featured_tags_collection! if @json['featuredTags'].present?
      check_links! if @account.fields.any?(&:requires_verification?)
    end

    @account
  rescue Oj::ParseError
    nil
  end

  private

  def create_account
    @account = Account.new
    @account.protocol          = :activitypub
    @account.username          = @username
    @account.domain            = @domain
    @account.private_key       = nil
    @account.suspended_at      = domain_block.created_at if auto_suspend?
    @account.suspension_origin = :local if auto_suspend?
    @account.silenced_at       = domain_block.created_at if auto_silence?
    @account.searchability     = :direct   # not null

    set_immediate_protocol_attributes!

    @account.save!
  end

  def update_account
    @account.last_webfingered_at = Time.now.utc unless @options[:only_key]
    @account.protocol            = :activitypub

    set_suspension!
    set_immediate_protocol_attributes!
    set_fetchable_key! unless @account.suspended? && @account.suspension_origin_local?
    set_immediate_attributes! unless @account.suspended?
    set_fetchable_attributes! unless @options[:only_key] || @account.suspended?

    @account.save_with_optional_media!
  end

  def set_immediate_protocol_attributes!
    @account.inbox_url               = @json['inbox'] || ''
    @account.outbox_url              = @json['outbox'] || ''
    @account.shared_inbox_url        = (@json['endpoints'].is_a?(Hash) ? @json['endpoints']['sharedInbox'] : @json['sharedInbox']) || ''
    @account.followers_url           = @json['followers'] || ''
    @account.url                     = url || @uri
    @account.uri                     = @uri
    @account.actor_type              = actor_type
    @account.created_at              = @json['published'] if @json['published'].present?
  end

  def set_immediate_attributes!
    @account.featured_collection_url = @json['featured'] || ''
    @account.devices_url             = @json['devices'] || ''
    @account.display_name            = @json['name'] || ''
    @account.note                    = @json['summary'] || ''
    @account.locked                  = @json['manuallyApprovesFollowers'] || false
    @account.fields                  = property_values || {}
    @account.also_known_as           = as_array(@json['alsoKnownAs'] || []).map { |item| value_or_id(item) }
    @account.discoverable            = @json['discoverable'] || false
    @account.indexable               = @json['indexable'] || false
    @account.searchability           = searchability_from_audience
    @account.settings                = other_settings
    @account.master_settings         = master_settings(@account.note)
    @account.memorial                = @json['memorial'] || false
  end

  def valid_account?
    display_name = @json['name']
    note = @json['summary']
    !Admin::NgWord.reject?(display_name) && !Admin::NgWord.reject?(note)
  end

  def set_fetchable_key!
    @account.public_key = public_key || ''
  end

  def set_fetchable_attributes!
    begin
      @account.avatar_remote_url = image_url('icon') || '' unless skip_download?
      @account.avatar = nil if @account.avatar_remote_url.blank?
    rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
      RedownloadAvatarWorker.perform_in(rand(30..600).seconds, @account.id)
    end
    begin
      @account.header_remote_url = image_url('image') || '' unless skip_download?
      @account.header = nil if @account.header_remote_url.blank?
    rescue Mastodon::UnexpectedResponseError, HTTP::TimeoutError, HTTP::ConnectionError, OpenSSL::SSL::SSLError
      RedownloadHeaderWorker.perform_in(rand(30..600).seconds, @account.id)
    end
    @account.statuses_count    = outbox_total_items    if outbox_total_items.present?
    @account.following_count   = following_total_items if following_total_items.present?
    @account.followers_count   = followers_total_items if followers_total_items.present?
    @account.hide_collections  = following_private? || followers_private?
    @account.moved_to_account  = @json['movedTo'].present? ? moved_account : nil
  end

  def set_suspension!
    return if @account.suspended? && @account.suspension_origin_local?

    if @account.suspended? && !@json['suspended']
      @account.unsuspend!
      @suspension_changed = true
    elsif !@account.suspended? && @json['suspended']
      @account.suspend!(origin: :remote)
      @suspension_changed = true
    end
  end

  def after_searchability_change!
    SearchabilityUpdateWorker.perform_async(@account.id) if @account.statuses.unset_searchability.exists?
  end

  def after_protocol_change!
    ActivityPub::PostUpgradeWorker.perform_async(@account.domain)
  end

  def after_key_change!
    RefollowWorker.perform_async(@account.id)
  end

  def after_suspension_change!
    if @account.suspended?
      Admin::SuspensionWorker.perform_async(@account.id)
    else
      Admin::UnsuspensionWorker.perform_async(@account.id)
    end
  end

  def check_featured_collection!
    ActivityPub::SynchronizeFeaturedCollectionWorker.perform_async(@account.id, { 'hashtag' => @json['featuredTags'].blank?, 'request_id' => @options[:request_id] })
  end

  def check_featured_tags_collection!
    ActivityPub::SynchronizeFeaturedTagsCollectionWorker.perform_async(@account.id, @json['featuredTags'])
  end

  def check_links!
    VerifyAccountLinksWorker.perform_async(@account.id)
  end

  def process_duplicate_accounts!
    return unless Account.where(uri: @account.uri).where.not(id: @account.id).exists?

    AccountMergingWorker.perform_async(@account.id)
  end

  def fetch_instance_info
    ActivityPub::FetchInstanceInfoWorker.perform_async(@account.domain) unless InstanceInfo.exists?(domain: @account.domain)
  end

  def actor_type
    if @json['type'].is_a?(Array)
      @json['type'].find { |type| ActivityPub::FetchRemoteAccountService::SUPPORTED_TYPES.include?(type) }
    else
      @json['type']
    end
  end

  def image_url(key)
    value = first_of_value(@json[key])

    return if value.nil?
    return value['url'] if value.is_a?(Hash)

    image = fetch_resource_without_id_validation(value)
    image['url'] if image
  end

  def public_key
    value = first_of_value(@json['publicKey'])

    return if value.nil?
    return value['publicKeyPem'] if value.is_a?(Hash)

    key = fetch_resource_without_id_validation(value)
    key['publicKeyPem'] if key
  end

  def url
    return if @json['url'].blank?

    url_candidate = url_to_href(@json['url'], 'text/html')

    if unsupported_uri_scheme?(url_candidate) || mismatching_origin?(url_candidate)
      nil
    else
      url_candidate
    end
  end

  def audience_searchable_by
    return nil if @json['searchableBy'].nil?

    @audience_searchable_by_processaccountservice = as_array(@json['searchableBy']).map { |x| value_or_id(x) }
  end

  def searchability_from_audience
    if audience_searchable_by.nil?
      bio = searchability_from_bio
      return bio unless bio.nil?

      return misskey_software? ? misskey_searchability_from_indexable : :direct
    end

    if audience_searchable_by.any? { |uri| ActivityPub::TagManager.instance.public_collection?(uri) }
      :public
    elsif audience_searchable_by.include?(@account.followers_url)
      :private
    elsif audience_searchable_by.include?('kmyblue:Limited') || audience_searchable_by.include?('as:Limited')
      :limited
    else
      :direct
    end
  end

  def searchability_from_bio
    note = @json['summary'] || ''
    return nil if note.blank?

    searchability_bio = note.scan(SCAN_SEARCHABILITY_FEDIBIRD_RE).first || note.scan(SCAN_SEARCHABILITY_RE).first
    return nil unless searchability_bio

    searchability = searchability_bio[0]
    return nil if searchability.nil?

    searchability = :public  if %w(public all_users).include?(searchability)
    searchability = :private if %w(followers followers_only).include?(searchability)
    searchability = :direct  if %w(reactors reacted_users_only).include?(searchability)
    searchability = :limited if %w(private nobody).include?(searchability)

    searchability
  end

  def misskey_searchability_from_indexable
    return :public if @json['indexable'].nil?

    @json['indexable'] ? :public : :limited
  end

  def instance_info
    @instance_info ||= InstanceInfo.find_by(domain: @domain)
  end

  def misskey_software?
    info = instance_info
    return false if info.nil?

    %w(misskey calckey).include?(info.software)
  end

  def subscribable_by
    return nil if @json['subscribableBy'].nil?

    @subscribable_by = as_array(@json['subscribableBy']).map { |x| value_or_id(x) }
  end

  def subscription_policy(note)
    if subscribable_by.nil?
      note.include?('[subscribable:no]') ? :block : :allow
    elsif subscribable_by.any? { |uri| ActivityPub::TagManager.instance.public_collection?(uri) }
      :allow
    elsif subscribable_by.include?(@account.followers_url)
      :followers_only
    else
      :block
    end
  end

  def master_settings(note)
    {
      'subscription_policy' => subscription_policy(note),
    }
  end

  def other_settings
    return {} unless @json['otherSetting'].is_a?(Array)

    @json['otherSetting'].each_with_object({}) { |v, h| h.merge!({ v['name'] => v['value'] }) if v['type'] == 'PropertyValue' }
  end

  def property_values
    return unless @json['attachment'].is_a?(Array)

    as_array(@json['attachment']).select { |attachment| attachment['type'] == 'PropertyValue' }.map { |attachment| attachment.slice('name', 'value') }
  end

  def mismatching_origin?(url)
    needle   = Addressable::URI.parse(url).host
    haystack = Addressable::URI.parse(@uri).host

    !haystack.casecmp(needle).zero?
  end

  def outbox_total_items
    collection_info('outbox').first
  end

  def following_total_items
    collection_info('following').first
  end

  def followers_total_items
    collection_info('followers').first
  end

  def following_private?
    !collection_info('following').last
  end

  def followers_private?
    !collection_info('followers').last
  end

  def collection_info(type)
    return [nil, nil] if @json[type].blank?
    return @collections[type] if @collections.key?(type)

    collection = fetch_resource_without_id_validation(@json[type])

    total_items = collection.is_a?(Hash) && collection['totalItems'].present? && collection['totalItems'].is_a?(Numeric) ? collection['totalItems'] : nil
    has_first_page = collection.is_a?(Hash) && collection['first'].present?
    @collections[type] = [total_items, has_first_page]
  rescue HTTP::Error, OpenSSL::SSL::SSLError, Mastodon::LengthValidationError
    @collections[type] = [nil, nil]
  end

  def moved_account
    account   = ActivityPub::TagManager.instance.uri_to_resource(@json['movedTo'], Account)
    account ||= ActivityPub::FetchRemoteAccountService.new.call(@json['movedTo'], id: true, break_on_redirect: true, request_id: @options[:request_id])
    account
  end

  def skip_download?
    @account.suspended? || domain_block&.reject_media?
  end

  def auto_suspend?
    domain_block&.suspend?
  end

  def auto_silence?
    domain_block&.silence?
  end

  def domain_block
    return @domain_block if defined?(@domain_block)

    @domain_block = DomainBlock.rule_for(@domain)
  end

  def key_changed?
    !@old_public_key.nil? && @old_public_key != @account.public_key
  end

  def suspension_changed?
    @suspension_changed
  end

  def clear_tombstones!
    Tombstone.where(account_id: @account.id).delete_all
  end

  def protocol_changed?
    !@old_protocol.nil? && @old_protocol != @account.protocol
  end

  def searchability_changed?
    !@old_searchability.nil? && @old_searchability != @account.searchability
  end

  def process_tags
    return if @json['tag'].blank?

    as_array(@json['tag']).each do |tag|
      process_emoji tag if equals_or_includes?(tag['type'], 'Emoji')
    end
  end

  def process_emoji(tag)
    return if skip_download?
    return if tag['name'].blank? || tag['icon'].blank? || tag['icon']['url'].blank?

    shortcode = tag['name'].delete(':')
    image_url = tag['icon']['url']
    uri       = tag['id']
    sensitive = (tag['isSensitive'].presence || false)
    license   = tag['license']
    updated   = tag['updated']
    emoji     = CustomEmoji.find_by(shortcode: shortcode, domain: @account.domain)

    return unless emoji.nil? || image_url != emoji.image_remote_url || (updated && updated >= emoji.updated_at)

    emoji ||= CustomEmoji.new(domain: @account.domain, shortcode: shortcode, uri: uri, is_sensitive: sensitive, license: license)
    emoji.image_remote_url = image_url
    emoji.save
  end
end
