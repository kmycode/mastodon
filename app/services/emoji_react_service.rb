# frozen_string_literal: true

class EmojiReactService < BaseService
  include Authorization
  include Payloadable
  include Redisable
  include Lockable

  # React a status with emoji and notify remote user
  # @param [Account] account
  # @param [Status] status
  # @param [string] name
  # @return [Favourite]
  def call(account, status, name)
    status = status.reblog if status.reblog? && !status.reblog.nil?
    authorize_with account, status, :emoji_reaction?
    @status = status

    emoji_reaction = nil

    with_redis_lock("emoji_reaction:#{status.id}") do
      emoji_reaction = EmojiReaction.find_by(account: account, status: status, name: name)
      raise Mastodon::ValidationError, I18n.t('reactions.errors.duplication') unless emoji_reaction.nil?

      shortcode, domain = name.split('@')
      custom_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)
      emoji_reaction = EmojiReaction.create!(account: account, status: status, name: shortcode, custom_emoji: custom_emoji)

      status.touch # rubocop:disable Rails/SkipsModelValidations
    end

    raise Mastodon::ValidationError, I18n.t('reactions.errors.duplication') if emoji_reaction.nil?

    Trends.statuses.register(status)

    create_notification(emoji_reaction)
    notify_to_followers(emoji_reaction)
    bump_potential_friendship(account, status)
    write_stream(emoji_reaction)
    forward_for_emoji_reaction!(emoji_reaction)
    relay_for_emoji_reaction!(emoji_reaction)
    relay_friend_for_emoji_reaction!(emoji_reaction)

    emoji_reaction
  end

  private

  def create_notification(emoji_reaction)
    status = emoji_reaction.status

    if status.account.local?
      if status.account.user&.setting_enable_emoji_reaction
        LocalNotificationWorker.perform_async(status.account_id, emoji_reaction.id, 'EmojiReaction', 'reaction') if status.account.user&.setting_emoji_reaction_streaming_notify_impl2
        LocalNotificationWorker.perform_async(status.account_id, emoji_reaction.id, 'EmojiReaction', 'emoji_reaction')
      end
    elsif status.account.activitypub?
      ActivityPub::DeliveryWorker.perform_async(build_json(emoji_reaction), emoji_reaction.account_id, status.account.inbox_url)
    end
  end

  def notify_to_followers(emoji_reaction)
    status = emoji_reaction.status

    return unless status.account.local?
    return if emoji_reaction.remote_custom_emoji?

    ActivityPub::RawDistributionWorker.perform_async(build_json(emoji_reaction), status.account_id)
  end

  def write_stream(emoji_reaction)
    emoji_group = emoji_reaction.status.emoji_reactions_grouped_by_name(nil, force: true)
                                .find { |reaction_group| reaction_group['name'] == emoji_reaction.name && (!reaction_group.key?(:domain) || reaction_group['domain'] == emoji_reaction.custom_emoji&.domain) }
    emoji_group['status_id'] = emoji_reaction.status_id.to_s
    DeliveryEmojiReactionWorker.perform_async(render_emoji_reaction(emoji_group), emoji_reaction.status_id, emoji_reaction.account_id)
  end

  def bump_potential_friendship(account, status)
    ActivityTracker.increment('activity:interactions')
    return if account.following?(status.account_id)

    PotentialFriendshipTracker.record(account.id, status.account_id, :emoji_reaction)
  end

  def build_json(emoji_reaction)
    @build_json = Oj.dump(serialize_payload(emoji_reaction, ActivityPub::EmojiReactionSerializer, signer: emoji_reaction.account))
  end

  def render_emoji_reaction(emoji_group)
    # @rendered_emoji_reaction ||= InlineRenderer.render(HashObject.new(emoji_group), nil, :emoji_reaction)
    @render_emoji_reaction ||= Oj.dump(event: :emoji_reaction, payload: emoji_group.to_json)
  end

  def forward_for_emoji_reaction!(emoji_reaction)
    return unless @status.local?

    ActivityPub::RawDistributionWorker.perform_async(build_json(emoji_reaction), @status.account.id, [@status.account.preferred_inbox_url])
  end

  def relay_for_emoji_reaction!(emoji_reaction)
    return unless @status.local? && @status.public_visibility?

    ActivityPub::DeliveryWorker.push_bulk(Relay.enabled.pluck(:inbox_url)) do |inbox_url|
      [build_json(emoji_reaction), @status.account.id, inbox_url]
    end
  end

  def relay_friend_for_emoji_reaction!(emoji_reaction)
    return unless @status.local? && @status.distributable_friend?

    ActivityPub::DeliveryWorker.push_bulk(FriendDomain.distributables.pluck(:inbox_url)) do |inbox_url|
      [build_json(emoji_reaction), @status.account.id, inbox_url]
    end
  end
end
