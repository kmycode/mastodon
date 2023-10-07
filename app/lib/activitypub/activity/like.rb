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

    # custom emoji
    emoji = nil
    if emoji_tag.present?
      emoji = process_emoji(emoji_tag)
      return if emoji.nil?
    end

    reaction = nil

    with_redis_lock("emoji_reaction:#{@original_status.id}") do
      return if EmojiReaction.where(account: @account, status: @original_status).count >= EmojiReaction::EMOJI_REACTION_PER_ACCOUNT_LIMIT
      return if EmojiReaction.find_by(account: @account, status: @original_status, name: shortcode)

      reaction = @original_status.emoji_reactions.create!(account: @account, name: shortcode, custom_emoji: emoji, uri: @json['id'])
    end

    Trends.statuses.register(@original_status)
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

  def process_emoji(tag)
    return if skip_download?

    custom_emoji_parser = ActivityPub::Parser::CustomEmojiParser.new(tag)

    return if custom_emoji_parser.shortcode.blank? || custom_emoji_parser.image_remote_url.blank?

    emoji = CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: @account.domain)

    return unless emoji.nil? || custom_emoji_parser.image_remote_url != emoji.image_remote_url || (custom_emoji_parser.updated_at && custom_emoji_parser.updated_at >= emoji.updated_at)

    domain = emoji_tag['domain'] || URI.split(custom_emoji_parser.uri)[2] || @account.domain
    domain = nil if domain == Rails.configuration.x.local_domain || domain == Rails.configuration.x.web_domain

    begin
      emoji ||= CustomEmoji.new(
        domain: domain,
        shortcode: custom_emoji_parser.shortcode,
        uri: custom_emoji_parser.uri,
        is_sensitive: custom_emoji_parser.is_sensitive,
        license: custom_emoji_parser.license
      )
      emoji.image_remote_url = custom_emoji_parser.image_remote_url
      emoji.save
    rescue Seahorse::Client::NetworkingError => e
      Rails.logger.warn "Error storing emoji: #{e}"
    end

    emoji
  end

  def skip_download?
    return @skip_download if defined?(@skip_download)

    @skip_download ||= DomainBlock.reject_media?(@account.domain)
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
