# frozen_string_literal: true

module StatusSearchConcern
  extend ActiveSupport::Concern

  included do
    scope :indexable, -> { without_reblogs.where(visibility: [:public, :login], searchability: nil).joins(:account).where(account: { indexable: true }) }
    scope :remote_dynamic_searchability, -> { remote.where(searchability: [:public, :public_unlisted, :private]) }
  end

  def searchable_by
    @searchable_by ||= begin
      ids = []

      ids << account_id if local?

      ids += mentioned_by
      ids += favourited_by
      ids += reblogged_by
      ids += bookmarked_by
      ids += emoji_reacted_by
      ids += referenced_by
      ids += voted_by if preloadable_poll.present?

      ids.uniq
    end
  end

  def mentioned_by
    @mentioned_by ||= local_mentioned.pluck(:id)
  end

  def favourited_by
    @favourited_by ||= local_favorited.pluck(:id)
  end

  def reblogged_by
    @reblogged_by ||= local_reblogged.pluck(:id)
  end

  def bookmarked_by
    @bookmarked_by ||= local_bookmarked.pluck(:id)
  end

  def bookmark_categoried_by
    @bookmark_categoried_by ||= local_bookmark_categoried.pluck(:id).uniq
  end

  def emoji_reacted_by
    @emoji_reacted_by ||= local_emoji_reacted.pluck(:id)
  end

  def referenced_by
    @referenced_by ||= local_referenced.pluck(:id)
  end

  def voted_by
    return [] if preloadable_poll.blank?

    @voted_by ||= preloadable_poll.local_voters.pluck(:id)
  end

  def searchable_text
    [
      spoiler_text,
      FormattingHelper.extract_status_plain_text(self),
      preloadable_poll&.options&.join("\n\n"),
      ordered_media_attachments.map(&:description).join("\n\n"),
    ].compact.join("\n\n")
  end

  def searchable_properties
    [].tap do |properties|
      properties << 'image' if ordered_media_attachments.any?(&:image?)
      properties << 'video' if ordered_media_attachments.any?(&:video?)
      properties << 'audio' if ordered_media_attachments.any?(&:audio?)
      properties << 'media' if with_media?
      properties << 'poll' if with_poll?
      properties << 'link' if with_preview_card?
      properties << 'embed' if preview_cards.any?(&:video?)
      properties << 'sensitive' if sensitive?
      properties << 'reply' if reply?
      properties << 'reference' if with_status_reference?
    end
  end
end
