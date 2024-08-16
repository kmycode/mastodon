# frozen_string_literal: true

class REST::NotifyEmojiReactionSerializer < ActiveModel::Serializer
  # Please update app/javascript/api_types/notification.ts when making changes to the attributes
  include RoutingHelper

  attributes :name

  attribute :count
  attribute :url, if: :custom_emoji?
  attribute :static_url, if: :custom_emoji?
  attribute :domain, if: :custom_emoji?
  attribute :width, if: :width?
  attribute :height, if: :height?
  attribute :me

  def count?
    object.respond_to?(:count)
  end

  def count
    count? ? object.count : 1
  end

  def custom_emoji?
    object.respond_to?(:custom_emoji) && object.custom_emoji.present?
  end

  def account_ids?
    object.respond_to?(:account_ids)
  end

  def url
    full_asset_url(object.custom_emoji.image.url)
  end

  def static_url
    full_asset_url(object.custom_emoji.image.url(:static))
  end

  def domain
    object.custom_emoji.domain
  end

  def width?
    custom_emoji? && (object.custom_emoji.respond_to?(:image_width) || object.custom_emoji.respond_to?(:width))
  end

  def height?
    custom_emoji? && (object.custom_emoji.respond_to?(:image_height) || object.custom_emoji.respond_to?(:height))
  end

  def width
    object.custom_emoji.respond_to?(:image_width) ? object.custom_emoji.image_width : object.custom_emoji.width
  end

  def height
    object.custom_emoji.respond_to?(:image_height) ? object.custom_emoji.image_height : object.custom_emoji.height
  end

  def me
    false
  end
end
