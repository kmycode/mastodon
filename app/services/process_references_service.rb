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
      @references_count = @status.reference_objects.count
      build_references_diff

      if @added_items.present? || @removed_items.present? || @changed_items.present?
        StatusReference.transaction do
          remove_old_references
          add_references
          change_reference_attributes

          @status.save!
        end

        create_notifications!
      end
    end

    launch_worker if @again
  end

  def self.need_process?(status, reference_parameters, urls, quote_urls)
    reference_parameters.any? || (urls || []).any? || (quote_urls || []).any? || FormattingHelper.extract_status_plain_text(status).scan(REFURL_EXP).pluck(3).uniq.any?
  end

  def self.perform_worker_async(status, reference_parameters, urls, quote_urls)
    return unless need_process?(status, reference_parameters, urls, quote_urls)

    ProcessReferencesWorker.perform_async(status.id, reference_parameters, urls, [], quote_urls || [])
  end

  def self.call_service(status, reference_parameters, urls, quote_urls = [])
    return unless need_process?(status, reference_parameters, urls, quote_urls)

    ProcessReferencesService.new.call(status, reference_parameters || [], urls: urls || [], fetch_remote: false, quote_urls: quote_urls)
  end

  def self.call_service_without_error(status, reference_parameters, urls, quote_urls = [])
    return unless need_process?(status, reference_parameters, urls, quote_urls)

    begin
      ProcessReferencesService.new.call(status, reference_parameters || [], urls: urls || [], quote_urls: quote_urls)
    rescue
      true
    end
  end

  private

  def build_old_references
    @status.reference_objects.pluck(:target_status_id, :attribute_type).to_h
  end

  def build_new_references
    scan_text_and_quotes.tap do |status_id_to_attributes|
      @reference_parameters.each do |status_id|
        id_num = status_id.to_i
        status_id_to_attributes[id_num] = 'BT' unless id_num.positive? && status_id_to_attributes.key?(id_num)
      end
    end
  end

  def build_references_diff
    olds = build_old_references
    news = build_new_references

    @changed_items = {}
    @added_items = {}
    @removed_items = {}

    news.each_key do |status_id|
      exist_attribute = olds[status_id]

      @added_items[status_id] = news[status_id] if exist_attribute.nil?
      @changed_items[status_id] = news[status_id] if olds.key?(status_id) && exist_attribute != news[status_id]
    end

    olds.each_key do |status_id|
      new_attribute = news[status_id]

      @removed_items[status_id] = olds[status_id] if new_attribute.nil?
    end
  end

  def scan_text_and_quotes
    text = extract_status_plain_text(@status)
    url_to_attributes = @urls.index_with('BT')
                             .merge(text.scan(REFURL_EXP).to_h { |result| [result[3], result[0]] })
                             .merge(@quote_urls.index_with('QT'))

    url_to_statuses = fetch_statuses(url_to_attributes.keys.uniq)

    @again = true if !@fetch_remote && url_to_statuses.values.any?(&:nil?)

    url_to_statuses.keys.to_h do |url|
      attribute = url_to_attributes[url] || 'BT'
      status = url_to_statuses[url]

      if status.present?
        quote = quote_attribute?(attribute)

        [status.id, !quote || quotable?(status) ? attribute : 'BT']
      else
        [url, attribute]
      end
    end
  end

  def quote_attribute?(attribute)
    %w(QT RE).include?(attribute)
  end

  def fetch_statuses(urls)
    urls.to_h do |url|
      status = url_to_status(url)
      @no_fetch_urls << url if !@fetch_remote && status.present?
      [url, status]
    end
  end

  def url_to_status(url)
    ResolveURLService.new.call(url, on_behalf_of: @status.account, fetch_remote: @fetch_remote && @no_fetch_urls.exclude?(url))
  end

  def quotable?(target_status)
    target_status.account.allow_quote? && (!@status.local? || StatusPolicy.new(@status.account, target_status).quote?)
  end

  def add_references
    return if @added_items.empty?

    @added_objects = []

    statuses = Status.where(id: @added_items.keys).to_a
    @added_items.each_key do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank?

      attribute_type = @added_items[status_id]
      quote = quote_attribute?(attribute_type)
      @added_objects << @status.reference_objects.new(target_status: status, attribute_type: attribute_type, quote: quote)

      @status.update!(quote_of_id: status_id) if quote

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
    return if @removed_items.empty?

    @removed_objects = []

    @status.reference_objects.where(target_status: @removed_items.keys).destroy_all
    @status.update!(quote_of_id: nil) if @status.quote_of_id.present? && @removed_items.key?(@status.quote_of_id)

    statuses = Status.where(id: @added_items.keys).to_a
    @removed_items.each_key do |status_id|
      status = statuses.find { |s| s.id == status_id }
      next if status.blank?

      status.decrement_count!(:status_referred_by_count)
      @references_count -= 1
    end
  end

  def change_reference_attributes
    return if @changed_items.empty?

    @changed_objects = []

    @status.reference_objects.where(target_status: @changed_items.keys).find_each do |ref|
      attribute_type = @changed_items[ref.target_status_id]
      quote = quote_attribute?(attribute_type)
      quote_change = ref.quote != quote

      ref.update!(attribute_type: attribute_type, quote: quote)

      next unless quote_change

      if quote
        ref.status.update!(quote_of_id: ref.target_status.id)
      else
        ref.status.update!(quote_of_id: nil)
      end
    end
  end

  def launch_worker
    ProcessReferencesWorker.perform_async(@status.id, @reference_parameters, @urls, @no_fetch_urls, @quote_urls)
  end
end
