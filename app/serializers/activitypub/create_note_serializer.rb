# frozen_string_literal: true

class ActivityPub::CreateNoteSerializer < ActivityPub::Serializer
  attributes :id, :type, :actor, :published, :to, :cc

  has_one :object, serializer: ActivityPub::NoteSerializer, if: -> { !use_bearcap? }
  attribute :bearcap, key: :object, if: -> { use_bearcap? }

  def id
    ActivityPub::TagManager.instance.activity_uri_for(object)
  end

  def type
    'Create'
  end

  def actor
    ActivityPub::TagManager.instance.uri_for(object.account)
  end

  def to
    for_friend? ? ActivityPub::TagManager.instance.to_for_friend(object) : ActivityPub::TagManager.instance.to(object)
  end

  def cc
    for_misskey? ? ActivityPub::TagManager.instance.cc_for_misskey(object) : ActivityPub::TagManager.instance.cc(object)
  end

  def published
    object.created_at.iso8601
  end

  def bearcap
    "bear:?#{{ u: ActivityPub::TagManager.instance.uri_for(object.proper), t: object.capability_tokens.first.token }.to_query}"
  end

  private

  def for_misskey?
    return instance_options[:for_misskey] if instance_options.key?(:for_misskey)

    false
  end

  def for_friend?
    return instance_options[:for_friend] if instance_options.key?(:for_friend)

    false
  end

  def use_bearcap?
    use_bearcap_option? && object.limited_visibility?
  end

  def use_bearcap_option?
    return instance_options[:use_bearcap] if instance_options.key?(:use_bearcap)

    true
  end
end
