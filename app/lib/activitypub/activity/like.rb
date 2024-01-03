# frozen_string_literal: true

class ActivityPub::Activity::Like < ActivityPub::Activity
  include Redisable
  include Lockable
  include JsonLdHelper

  def perform
    @original_status = status_from_uri(object_uri)

    return if @original_status.nil? || delete_arrived_first?(@json['id']) || block_domain? || reject_favourite?

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
    return if silence_domain? && (!@original_status.local? || !@original_status.account.following?(@account))

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

    NotifyService.new.call(@original_status.account, :emoji_reaction, reaction) if @original_status.account.local?
  rescue Seahorse::Client::NetworkingError, ActiveRecord::RecordInvalid
    nil
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
    custom_emoji_parser = ActivityPub::Parser::CustomEmojiParser.new(tag)

    return if custom_emoji_parser.shortcode.blank? || custom_emoji_parser.image_remote_url.blank?

    domain = URI.split(custom_emoji_parser.uri)[2] || @account.domain

    if domain == Rails.configuration.x.local_domain || domain == Rails.configuration.x.web_domain
      # Block overwriting remote-but-local data
      return CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: nil)
    end

    return if domain.present? && skip_download?(domain)

    emoji = CustomEmoji.find_by(shortcode: custom_emoji_parser.shortcode, domain: domain)

    return emoji unless emoji.nil? ||
                        custom_emoji_parser.image_remote_url != emoji.image_remote_url ||
                        (custom_emoji_parser.updated_at && custom_emoji_parser.updated_at >= emoji.updated_at) ||
                        custom_emoji_parser.license != emoji.license

    custom_emoji_parser = original_emoji_parser(custom_emoji_parser) if @account.domain != domain
    return if custom_emoji_parser.nil?

    begin
      emoji ||= CustomEmoji.new(
        domain: domain,
        shortcode: custom_emoji_parser.shortcode,
        uri: custom_emoji_parser.uri
      )
      emoji.image_remote_url = custom_emoji_parser.image_remote_url
      emoji.license = custom_emoji_parser.license
      emoji.is_sensitive = custom_emoji_parser.is_sensitive
      emoji.aliases = custom_emoji_parser.aliases
      emoji.save
    rescue Seahorse::Client::NetworkingError => e
      Rails.logger.warn "Error storing emoji: #{e}"
    end

    emoji
  end

  def original_emoji_parser(custom_emoji_parser)
    uri = custom_emoji_parser.uri
    emoji = fetch_resource_without_id_validation(uri)
    return nil unless emoji

    parser = ActivityPub::Parser::CustomEmojiParser.new(emoji)
    return nil unless parser.uri == uri && custom_emoji_parser.shortcode == parser.shortcode

    parser
  end

  def skip_download?(domain)
    return true if DomainBlock.reject_media?(domain)
    return false if @account.domain == domain

    DomainBlock.blocked?(domain) || (DomainBlock.silence?(domain) && !@original_status.account.following?(@account))
  end

  def block_domain?
    DomainBlock.blocked?(@account.domain)
  end

  def silence_domain?
    DomainBlock.silence?(@account.domain)
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
    DeliveryEmojiReactionWorker.perform_async(render_emoji_reaction(emoji_group), @original_status.id, emoji_reaction.account_id) if @original_status.local? ? Setting.streaming_local_emoji_reaction : Setting.streaming_other_servers_emoji_reaction
  end

  def render_emoji_reaction(emoji_group)
    @render_emoji_reaction ||= Oj.dump(event: :emoji_reaction, payload: emoji_group.to_json)
  end
end
