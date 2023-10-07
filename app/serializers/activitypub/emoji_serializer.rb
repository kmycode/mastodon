# frozen_string_literal: true

class ActivityPub::EmojiSerializer < ActivityPub::Serializer
  include RoutingHelper

  context_extensions :emoji

  attributes :id, :type, :domain, :name, :updated

  has_one :icon, serializer: ActivityPub::ImageSerializer

  def id
    if object.uri.nil? || object.domain.nil?
      ActivityPub::TagManager.instance.uri_for(object)
    else
      object.uri
    end
  end

  def type
    'Emoji'
  end

  def domain
    object.domain.presence || Rails.configuration.x.local_domain
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
