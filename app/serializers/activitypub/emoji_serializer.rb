# frozen_string_literal: true

class ActivityPub::EmojiSerializer < ActivityPub::Serializer
  include RoutingHelper

  context_extensions :emoji, :license, :keywords, :misskey_license

  attributes :id, :type, :name, :keywords, :is_sensitive, :updated

  attribute :license, if: :license?
  has_one :misskey_license, key: :_misskey_license, if: :license?, serializer: ActivityPub::MisskeyEmojiLicenseSerializer

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

  def misskey_license
    ActivityPub::MisskeyEmojiLicensePresenter.new(free_text: object.license)
  end

  def license?
    object.license.present?
  end
end
