# frozen_string_literal: true

class REST::Admin::DomainBlockSerializer < ActiveModel::Serializer
  attributes :id, :domain, :created_at, :severity,
             :reject_media, :reject_favourite, :reject_reply, :reject_reports,
             :reject_reply_exclude_followers, :reject_send_sensitive,
             :reject_hashtag, :reject_straight_follow, :reject_new_follow, :reject_friend, :detect_invalid_subscription,
             :private_comment, :public_comment, :obfuscate

  def id
    object.id.to_s
  end
end
