# frozen_string_literal: true

class ActivityPub::Activity::Follow < ActivityPub::Activity
  include Payloadable

  def perform
    return request_follow_for_friend if friend_follow?

    target_account = account_from_uri(object_uri)

    return if target_account.nil? || !target_account.local? || delete_arrived_first?(@json['id'])

    # Update id of already-existing follow requests
    existing_follow_request = ::FollowRequest.find_by(account: @account, target_account: target_account)
    unless existing_follow_request.nil?
      existing_follow_request.update!(uri: @json['id'])
      return
    end

    if target_account.blocking?(@account) || target_account.domain_blocking?(@account.domain) || target_account.moved? || target_account.instance_actor? || block_new_follow?
      reject_follow_request!(target_account)
      return
    end

    # Fast-forward repeat follow requests
    existing_follow = ::Follow.find_by(account: @account, target_account: target_account)
    unless existing_follow.nil?
      existing_follow.update!(uri: @json['id'])
      AuthorizeFollowService.new.call(@account, target_account, skip_follow_request: true, follow_request_uri: @json['id'])
      return
    end

    follow_request = FollowRequest.create!(account: @account, target_account: target_account, uri: @json['id'])

    if target_account.locked? || @account.silenced? || block_straight_follow? || (@account.bot? && target_account.user&.setting_lock_follow_from_bot)
      LocalNotificationWorker.perform_async(target_account.id, follow_request.id, 'FollowRequest', 'follow_request')
    else
      AuthorizeFollowService.new.call(@account, target_account)
      LocalNotificationWorker.perform_async(target_account.id, ::Follow.find_by(account: @account, target_account: target_account).id, 'Follow', 'follow')
    end
  end

  def reject_follow_request!(target_account)
    json = Oj.dump(serialize_payload(FollowRequest.new(account: @account, target_account: target_account, uri: @json['id']), ActivityPub::RejectFollowSerializer))
    ActivityPub::DeliveryWorker.perform_async(json, target_account.id, @account.inbox_url)
  end

  def request_follow_for_friend
    friend.update!(passive_state: :pending, passive_follow_activity_id: @json['id'])
  end

  def friend
    @friend ||= FriendDomain.find_by(domain: @account.domain, passive_state: [:idle, :pending]) if @account.domain.present? && @json['object'] == ActivityPub::TagManager::COLLECTIONS[:public]
  end

  def friend_follow?
    friend.present?
  end

  def block_straight_follow?
    @block_straight_follow ||= DomainBlock.reject_straight_follow?(@account.domain)
  end

  def block_new_follow?
    @block_new_follow ||= DomainBlock.reject_new_follow?(@account.domain)
  end
end
