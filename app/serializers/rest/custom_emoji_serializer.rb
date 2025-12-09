# frozen_string_literal: true

class REST::CustomEmojiSerializer < REST::CustomEmojiSlimSerializer
  include RoutingHelper

  # Please update `app/javascript/mastodon/api_types/custom_emoji.ts` when making changes to the attributes

  attribute :aliases
  attribute :license

  attribute :category, if: :category_loaded?
  attribute :featured, if: :category_loaded?

  def url
    full_asset_url(object.image.url)
  end

  def static_url
    full_asset_url(object.image.url(:static))
  end

  def category
    object.category.name
  end

  def featured
    object.featured?
  end

  def category_loaded?
    object.association(:category).loaded? && object.category.present?
  end

  def aliases
    if object.respond_to?(:aliases) && object.aliases.present?
      object.aliases.compact_blank
    else
      []
    end
  end
end
