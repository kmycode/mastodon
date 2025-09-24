# frozen_string_literal: true

class ProcessReferencesService < BaseService
  include Payloadable
  include FormattingHelper
  include Redisable
  include Lockable

  DOMAIN = ENV['WEB_DOMAIN'] || ENV.fetch('LOCAL_DOMAIN', nil)
  REFURL_EXP = /(RT|QT|BT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/
  QUOTEURL_EXP = /(QT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/
  MAX_REFERENCES = 5

  def call(status, reference_parameters, urls: nil, fetch_remote: true, no_fetch_urls: nil)
    @status = status
    @reference_parameters = reference_parameters || []
    @urls = urls || []
    @no_fetch_urls = no_fetch_urls || []
    @fetch_remote = fetch_remote
    @again = false

    @attributes = {}

    with_redis_lock("process_status_refs:#{@status.id}") do
      @references_count = @status.reference_objects.count
      build_references_diff

      if @added_status_ids.present? || @removed_status_ids.present?
        StatusReference.transaction do
          remove_old_references
          add_references

          @status.save!
        end

        create_notifications!
      end
    end

    launch_worker if @again
  end

  def self.need_process?(status, reference_parameters, urls, quote: nil)
    reference_parameters.any? || [urls, quote].flatten.compact.any? || FormattingHelper.extract_status_plain_text(status).scan(REFURL_EXP).pluck(3).uniq.any?
  end

  def self.extract_uris(text, remote: false)
    return text.scan(REFURL_EXP).pluck(3) unless remote

    PlainTextFormatter.new(text, false).to_s.scan(REFURL_EXP).pluck(3)
  end

  def self.extract_quote(text)
    text.scan(QUOTEURL_EXP).pick(3)
  end

  def self.call_service(status, reference_parameters, urls, quote: nil)
    return unless need_process?(status, reference_parameters, urls, quote: quote)

    ProcessReferencesService.new.call(status, reference_parameters || [], urls: [urls, quote].flatten.compact || [], fetch_remote: false)
  end

  def self.call_service_without_error(status, reference_parameters, urls, quote: nil)
    return unless need_process?(status, reference_parameters, urls, quote: quote)

    begin
      ProcessReferencesService.new.call(status, reference_parameters || [], urls: [urls, quote].flatten.compact)
    rescue
      true
    end
  end

  private

  def build_old_references
    @status.reference_objects.pluck(:target_status_id)
  end

  def build_new_references
    scan_text_and_quotes
  end

  def build_references_diff
    olds = build_old_references
    news = build_new_references

    @added_status_ids = (news - olds).uniq
    @removed_status_ids = (olds - news).uniq
  end

  def scan_text_and_quotes
    text = extract_status_plain_text(@status)
    @urls.index_with('BT')
         .merge(text.scan(REFURL_EXP).to_h { |result| [result[3], result[0]] })

    detected_urls = (@urls + text.scan(REFURL_EXP).pluck(3)).uniq
    url_to_statuses = fetch_statuses(detected_urls)

    @again = true if !@fetch_remote && url_to_statuses.values.any?(&:nil?)

    url_to_statuses.keys.filter_map { |url| url_to_statuses[url]&.id }
  end

  def fetch_statuses(urls)
    urls.to_h do |url|
      status = url_to_status(url)
      @no_fetch_urls << url if !@fetch_remote && status.present?
      [url, status]
    end
  end

  def url_to_status(url)
    status   = ActivityPub::TagManager.instance.uri_to_resource(url, Status, url: true)
    status ||= ResolveURLService.new.call(url, on_behalf_of: @status.account) unless bad_url_to_fetch?(url)
    status
  end

  def bad_url_to_fetch?(url)
    uri = Addressable::URI.parse(url).normalize

    !@fetch_remote || @no_fetch_urls.include?(url) || uri.host.blank? || Setting.stop_fetch_activity_domains&.include?(uri.host)
  end

  def referrable?(target_status)
    return false if target_status.nil?
    return @referrable if defined?(@referrable)

    @referrable = StatusPolicy.new(@status.account, target_status).show?
  end

  def add_references
    return if @added_status_ids.empty?

    @added_objects = []

    statuses = Status.where(id: @added_status_ids).to_a
    @added_status_ids.each do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank? || !referrable?(status)

      @added_objects << @status.reference_objects.new(target_status: status)

      status.increment_count!(:status_referred_by_count)
      @references_count += 1

      break if @references_count >= MAX_REFERENCES
    end
  end

  def create_notifications!
    return if @added_objects.blank?

    local_reference_objects = @added_objects.filter { |ref| ref.target_status.account.local? && StatusPolicy.new(ref.target_status.account, ref.status).show? }
    return if local_reference_objects.empty?

    LocalNotificationWorker.push_bulk(local_reference_objects) do |ref|
      [ref.target_status.account_id, ref.id, 'StatusReference', 'status_reference']
    end
  end

  def remove_old_references
    return if @removed_status_ids.empty?

    @removed_objects = []

    @status.reference_objects.where(target_status: @removed_status_ids).destroy_all

    statuses = Status.where(id: @removed_status_ids).to_a
    @removed_status_ids.each do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank?

      status.decrement_count!(:status_referred_by_count)
      @references_count -= 1
    end
  end

  def launch_worker
    ProcessReferencesWorker.perform_async(@status.id, @reference_parameters, @urls, @no_fetch_urls)
  end
end
