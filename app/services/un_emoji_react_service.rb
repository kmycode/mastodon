# frozen_string_literal: true

class UnEmojiReactService < BaseService
  include Redisable
  include Payloadable

  def call(account, status, emoji_reaction = nil)
    @account = account
    @status = status

    if emoji_reaction
      emoji_reaction.destroy!

      status.touch # rubocop:disable Rails/SkipsModelValidations

      create_notification(emoji_reaction) if !@status.account.local? && @status.account.activitypub?
      notify_to_followers(emoji_reaction)
      write_stream(emoji_reaction)

      relay_for_undo_emoji_reaction!(emoji_reaction)
      relay_friend_for_undo_emoji_reaction!(emoji_reaction)
    else
      bulk(account, status)
    end
    emoji_reaction
  end

  private

  def bulk(account, status)
    EmojiReaction.where(account: account, status: status).each do |emoji_reaction|
      call(account, status, emoji_reaction)
    end
  end

  def create_notification(emoji_reaction)
    ActivityPub::DeliveryWorker.perform_async(build_json(emoji_reaction), emoji_reaction.account_id, @status.account.inbox_url)
  end

  def notify_to_followers(emoji_reaction)
    ActivityPub::RawDistributionWorker.perform_async(build_json(emoji_reaction), @account.id)
  end

  def write_stream(emoji_reaction)
    emoji_group = @status.emoji_reactions_grouped_by_name
                         .find { |reaction_group| reaction_group['name'] == emoji_reaction.name && (!reaction_group.key?(:domain) || reaction_group['domain'] == emoji_reaction.custom_emoji&.domain) }
    if emoji_group
      emoji_group['status_id'] = @status.id.to_s
    else
      # name: emoji_reaction.name, count: 0, domain: emoji_reaction.domain
      emoji_group = { 'name' => emoji_reaction.name, 'count' => 0, 'account_ids' => [], 'status_id' => @status.id.to_s }
      emoji_group['domain'] = emoji_reaction.custom_emoji.domain if emoji_reaction.custom_emoji
    end
    DeliveryEmojiReactionWorker.perform_async(render_emoji_reaction(emoji_group), @status.id, emoji_reaction.account_id)
  end

  def build_json(emoji_reaction)
    @build_json = Oj.dump(serialize_payload(emoji_reaction, ActivityPub::UndoEmojiReactionSerializer, signer: emoji_reaction.account))
  end

  def render_emoji_reaction(emoji_group)
    # @rendered_emoji_reaction ||= InlineRenderer.render(emoji_group, nil, :emoji_reaction)
    Oj.dump(event: :emoji_reaction, payload: emoji_group.to_json)
  end

  def relay_for_undo_emoji_reaction!(emoji_reaction)
    return unless @status.local? && @status.public_visibility?

    ActivityPub::DeliveryWorker.push_bulk(Relay.enabled.pluck(:inbox_url)) do |inbox_url|
      [build_json(emoji_reaction), @status.account.id, inbox_url]
    end
  end

  def relay_friend_for_undo_emoji_reaction!(emoji_reaction)
    return unless @status.local? && @status.distributable_friend?

    ActivityPub::DeliveryWorker.push_bulk(FriendDomain.distributables.pluck(:inbox_url)) do |inbox_url|
      [build_json(emoji_reaction), @status.account.id, inbox_url]
    end
  end
end
