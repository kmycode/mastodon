# frozen_string_literal: true

class ActivityPub::Activity::Like < ActivityPub::Activity
  include Redisable
  include Lockable

  def perform
    @original_status = status_from_uri(object_uri)

    return if @original_status.nil? || delete_arrived_first?(@json['id']) || reject_favourite?

    if shortcode.nil? || !Setting.enable_emoji_reaction
      process_favourite
    else
      process_emoji_reaction
    end
  end

  private

  def reject_favourite?
    @reject_favourite ||= DomainBlock.reject_favourite?(@account.domain)
  end

  def process_favourite
    return if @account.favourited?(@original_status)

    favourite = @original_status.favourites.create!(account: @account)

    LocalNotificationWorker.perform_async(@original_status.account_id, favourite.id, 'Favourite', 'favourite')
    Trends.statuses.register(@original_status)
  end

  def process_emoji_reaction
    return if !@original_status.account.local? && !Setting.receive_other_servers_emoji_reaction

    if emoji_tag.present?
      return if emoji_tag['id'].blank? || emoji_tag['name'].blank? || emoji_tag['icon'].blank? || emoji_tag['icon']['url'].blank?

      image_url = emoji_tag['icon']['url']
      uri       = emoji_tag['id']
      domain    = emoji_tag['domain'] || URI.split(uri)[2]

      emoji = CustomEmoji.find_or_create_by!(shortcode: shortcode, domain: domain) do |emoji_data|
        emoji_data.uri              = uri
        emoji_data.image_remote_url = image_url
      end

      Trends.statuses.register(@original_status)
    end

    reaction = nil

    with_redis_lock("emoji_reaction:#{@original_status.id}") do
      return if EmojiReaction.where(account: @account, status: @original_status).count >= EmojiReaction::EMOJI_REACTION_PER_ACCOUNT_LIMIT
      return if EmojiReaction.find_by(account: @account, status: @original_status, name: shortcode)

      reaction = @original_status.emoji_reactions.create!(account: @account, name: shortcode, custom_emoji: emoji, uri: @json['id'])
    end

    write_stream(reaction)

    if @original_status.account.local?
      NotifyService.new.call(@original_status.account, :emoji_reaction, reaction)
      forward_for_emoji_reaction
      relay_for_emoji_reaction
    end
  rescue Seahorse::Client::NetworkingError
    nil
  end

  def forward_for_emoji_reaction
    return if @json['signature'].blank?

    ActivityPub::RawDistributionWorker.perform_async(Oj.dump(@json), @original_status.account.id, [@account.preferred_inbox_url])
  end

  def relay_for_emoji_reaction
    return unless @json['signature'].present? && @original_status.public_visibility?

    ActivityPub::DeliveryWorker.push_bulk(Relay.enabled.pluck(:inbox_url)) do |inbox_url|
      [Oj.dump(@json), @original_status.account.id, inbox_url]
    end
  end

  def shortcode
    return @shortcode if defined?(@shortcode)

    @shortcode = begin
      if @json['_misskey_reaction'] == '⭐'
        nil
      else
        @json['content']&.delete(':')
      end
    end
  end

  def misskey_favourite?
    misskey_shortcode = @json['_misskey_reaction']&.delete(':')

    misskey_shortcode == shortcode && misskey_shortcode == '⭐'
  end

  def emoji_tag
    return @emoji_tag if defined?(@emoji_tag)

    @emoji_tag = @json['tag'].is_a?(Array) ? @json['tag']&.first : @json['tag']
  end

  def write_stream(emoji_reaction)
    emoji_group = @original_status.emoji_reactions_grouped_by_name(nil, force: true)
                                  .find { |reaction_group| reaction_group['name'] == emoji_reaction.name && (!reaction_group.key?(:domain) || reaction_group['domain'] == emoji_reaction.custom_emoji&.domain) }
    emoji_group['status_id'] = @original_status.id.to_s
    DeliveryEmojiReactionWorker.perform_async(render_emoji_reaction(emoji_group), @original_status.id, emoji_reaction.account_id) if @original_status.local? || Setting.streaming_other_servers_emoji_reaction
  end

  def render_emoji_reaction(emoji_group)
    @render_emoji_reaction ||= Oj.dump(event: :emoji_reaction, payload: emoji_group.to_json)
  end
end
