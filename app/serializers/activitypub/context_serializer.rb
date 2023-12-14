# frozen_string_literal: true

class ActivityPub::ContextSerializer < ActivityPub::Serializer
  include RoutingHelper

  attributes :id, :type, :inbox

  def id
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def type
    'Group'
  end

  def inbox
    return '' if object.ancestor_status.nil?

    account_inbox_url(object.ancestor_status.account)
  end
end
