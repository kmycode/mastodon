# frozen_string_literal: true

class FeedInsertWorker
  include Sidekiq::Worker
  include DatabaseHelper

  def perform(status_id, id, type = 'home', options = {})
    with_primary do
      @type      = type.to_sym
      @status    = Status.find(status_id)
      @options   = options.symbolize_keys
      @antenna   = Antenna.find(@options[:antenna_id]) if @options[:antenna_id].present?
      @pushed    = false

      case @type
      when :home, :tags
        @follower = Account.find(id)
      when :list
        @list     = List.find(id)
        @follower = @list.account
      when :antenna
        @antenna  = Antenna.find(id)
        @follower = @antenna.account
      end
    end

    with_read_replica do
      check_and_insert
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def check_and_insert
    if feed_filtered?
      perform_unpush if update?
    else
      perform_push
      perform_notify if notify?
      perform_notify_for_list if notify_for_list?
    end
  end

  def feed_filtered?
    case @type
    when :home, :antenna
      FeedManager.instance.filter?(:home, @status, @follower)
    when :tags
      FeedManager.instance.filter?(:tags, @status, @follower)
    when :list
      FeedManager.instance.filter?(:list, @status, @list, stl_home?)
    end
  end

  def notify?
    return false if @type != :home || @status.reblog? || (@status.reply? && @status.in_reply_to_account_id != @status.account_id)

    Follow.find_by(account: @follower, target_account: @status.account)&.notify?
  end

  def notify_for_list?
    return false if @type != :list || update? || !@pushed

    @list.notify?
  end

  def perform_push
    if @antenna.nil? || @antenna.insert_feeds
      case @type
      when :home, :tags
        @pushed = FeedManager.instance.push_to_home(@follower, @status, update: update?)
      when :list
        @pushed = FeedManager.instance.push_to_list(@list, @status, update: update?)
      end
    end

    return if @antenna.nil?

    FeedManager.instance.push_to_antenna(@antenna, @status, update: update?)
  end

  def perform_unpush
    case @type
    when :home, :tags
      FeedManager.instance.unpush_from_home(@follower, @status, update: true)
    when :list
      FeedManager.instance.unpush_from_list(@list, @status, update: true)
    end

    return if @antenna.nil?

    FeedManager.instance.unpush_from_antenna(@antenna, @status, update: true)
  end

  def perform_notify
    LocalNotificationWorker.perform_async(@follower.id, @status.id, 'Status', 'status')
  end

  def perform_notify_for_list
    list_status = ListStatus.create!(list: @list, status: @status)
    LocalNotificationWorker.perform_async(@list.account_id, list_status.id, 'ListStatus', 'list_status')
  end

  def update?
    @options[:update]
  end

  def stl_home?
    @options[:stl_home]
  end
end
