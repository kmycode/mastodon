# frozen_string_literal: true

class ActivityPub::EmojiSerializer < ActivityPub::Serializer
  include RoutingHelper

  context_extensions :emoji, :license, :keywords

  attributes :id, :type, :name, :keywords, :is_sensitive, :updated

  attribute :license, if: -> { object.license.present? }

  has_one :icon, serializer: ActivityPub::ImageSerializer

  def id
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def type
    'Emoji'
  end

  def keywords
    object.aliases
  end

  def icon
    object.image
  end

  def updated
    object.updated_at.iso8601
  end

  def name
    ":#{object.shortcode}:"
  end
end
