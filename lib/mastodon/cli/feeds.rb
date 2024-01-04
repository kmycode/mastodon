# frozen_string_literal: true

require_relative 'base'

module Mastodon::CLI
  class Feeds < Base
    include Redisable

    option :all, type: :boolean, default: false
    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :verbose, type: :boolean, aliases: [:v]
    option :dry_run, type: :boolean, default: false
    desc 'build [USERNAME]', 'Build home and list feeds for one or all users'
    long_desc <<-LONG_DESC
      Build home and list feeds that are stored in Redis from the database.

      With the --all option, all active users will be processed.
      Otherwise, a single user specified by USERNAME.
    LONG_DESC
    def build(username = nil)
      if options[:all] || username.nil?
        processed, = parallelize_with_progress(active_user_accounts) do |account|
          PrecomputeFeedService.new.call(account) unless dry_run?
        end

        say("Regenerated feeds for #{processed} accounts #{dry_run_mode_suffix}", :green, true)
      elsif username.present?
        account = Account.find_local(username)

        if account.nil?
          say('No such account', :red)
          exit(1)
        end

        PrecomputeFeedService.new.call(account) unless dry_run?

        say("OK #{dry_run_mode_suffix}", :green, true)
      else
        say('No account(s) given', :red)
        exit(1)
      end
    end

    desc 'clear', 'Remove all home and list feeds from Redis'
    def clear
      keys = redis.keys('feed:*')
      redis.del(keys)
      say('OK', :green)
    end

    desc 'remove_legacy', 'Remove old list and antenna feeds from Redis'
    def remove_legacy
      current_id = 1
      List.reorder(:id).select(:id).find_in_batches do |lists|
        current_id = remove_legacy_feeds(:list, lists, current_id)
      end

      current_id = 1
      Antenna.reorder(:id).select(:id).find_in_batches do |antennas|
        current_id = remove_legacy_feeds(:antenna, antennas, current_id)
      end

      say('OK', :green)
    end

    private

    def active_user_accounts
      Account.joins(:user).merge(User.active)
    end

    def remove_legacy_feeds(type, items, current_id)
      exist_ids = items.pluck(:id)
      last_id = exist_ids.max

      ids = Range.new(current_id, last_id).to_a - exist_ids
      FeedManager.instance.clean_feeds!(type, ids)

      last_id + 1
    end
  end
end
