# frozen_string_literal: true

class ProcessReferencesService < BaseService
  include Payloadable
  include FormattingHelper
  include Redisable
  include Lockable

  DOMAIN = ENV['WEB_DOMAIN'] || ENV.fetch('LOCAL_DOMAIN', nil)
  REFURL_EXP = /(RT|QT|BT|RN|RE)((:|;)?\s+|:|;)(#{URI::DEFAULT_PARSER.make_regexp(%w(http https))})/
  MAX_REFERENCES = 5

  def call(status, reference_parameters, urls: nil, fetch_remote: true, no_fetch_urls: nil, quote_urls: nil)
    @status = status
    @reference_parameters = reference_parameters || []
    @quote_urls = quote_urls || []
    @urls = (urls - @quote_urls) || []
    @no_fetch_urls = no_fetch_urls || []
    @fetch_remote = fetch_remote
    @again = false

    @attributes = {}

    with_redis_lock("process_status_refs:#{@status.id}") do
      @references_count = old_references.size

      if added_references.size.positive? || removed_references.size.positive?
        StatusReference.transaction do
          remove_old_references
          add_references

          @status.save!
        end

        create_notifications!
      end

      Rails.cache.delete("status_reference:#{@status.id}")
    end

    launch_worker if @again
  end

  def self.need_process?(status, reference_parameters, urls)
    reference_parameters.any? || (urls || []).any? || FormattingHelper.extract_status_plain_text(status).scan(REFURL_EXP).pluck(3).uniq.any?
  end

  def self.perform_worker_async(status, reference_parameters, urls, quote_urls = [])
    return unless need_process?(status, reference_parameters, urls)

    Rails.cache.write("status_reference:#{status.id}", true, expires_in: 10.minutes)
    ProcessReferencesWorker.perform_async(status.id, reference_parameters, urls, [], quote_urls || [])
  end

  def self.call_service(status, reference_parameters, urls, quote_urls = [])
    return unless need_process?(status, reference_parameters, urls)

    ProcessReferencesService.new.call(status, reference_parameters || [], urls: urls || [], fetch_remote: false, quote_urls: quote_urls)
  end

  private

  def references
    @references ||= @reference_parameters + scan_text! + quote_status_ids
  end

  def old_references
    @old_references ||= @status.references.pluck(:id)
  end

  def added_references
    (references - old_references).uniq
  end

  def removed_references
    (old_references - references).uniq
  end

  def scan_text!
    text = extract_status_plain_text(@status)
    scaned = text.scan(REFURL_EXP)
    statuses = fetch_statuses!(scaned.pluck(3).uniq)

    @again = true if !@fetch_remote && statuses.any?(&:nil?)
    @attributes = scaned.pluck(0).zip(statuses).to_h { |pair| [pair[1]&.id, pair[0]] }

    @scan_text = statuses.compact.map(&:id).uniq.filter { |status_id| !status_id.zero? }
  end

  def fetch_statuses!(urls)
    target_urls = urls + @urls

    target_urls.map do |url|
      status = url_to_status(url)
      @no_fetch_urls << url if !@fetch_remote && status.present? && status.local?
      status
    end
  end

  def url_to_status(url)
    ResolveURLService.new.call(url, on_behalf_of: @status.account, fetch_remote: @fetch_remote && @no_fetch_urls.exclude?(url))
  end

  def quote_status_ids
    @quote_status_ids ||= @quote_urls.filter_map { |url| url_to_status(url) }.map(&:id)
  end

  def quotable?(target_status)
    StatusPolicy.new(@status.account, target_status).quote?
  end

  def add_references
    return if added_references.empty?

    @added_objects = []

    statuses = Status.where(id: added_references)
    statuses.each do |status|
      attribute_type = quote_status_ids.include?(status.id) ? 'QT' : @attributes[status.id]
      attribute_type = 'BT' unless quotable?(status)
      @added_objects << @status.reference_objects.new(target_status: status, attribute_type: attribute_type, quote: attribute_type.casecmp('QT').zero?)
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
    return if removed_references.empty?

    statuses = Status.where(id: removed_references)

    @status.reference_objects.where(target_status: statuses).destroy_all
    statuses.each do |status|
      status.decrement_count!(:status_referred_by_count)
      @references_count -= 1
    end
  end

  def launch_worker
    ProcessReferencesWorker.perform_async(@status.id, @reference_parameters, @urls, @no_fetch_urls, @quote_urls)
  end
end
