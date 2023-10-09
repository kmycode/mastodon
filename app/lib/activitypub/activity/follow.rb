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

    if target_account.locked? || @account.silenced? || block_straight_follow? || ((@account.bot? || proxy_account?) && target_account.user&.setting_lock_follow_from_bot)
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
    already_accepted = false

    if friend.present?
      already_accepted = friend.they_are_accepted?
      friend.update!(passive_state: :pending, passive_follow_activity_id: @json['id'])
    else
      @friend = FriendDomain.create!(domain: @account.domain, passive_state: :pending, passive_follow_activity_id: @json['id'])
    end

    if already_accepted || friend.unlocked || Setting.unlocked_friend
      friend.accept!
    else
      # Notify for admin even if unlocked
      notify_staff_about_pending_friend_server!
    end
  end

  def friend
    @friend ||= FriendDomain.find_by(domain: @account.domain) if @account.domain.present?
  end

  def friend_follow?
    @json['object'] == ActivityPub::TagManager::COLLECTIONS[:public] && !block_friend?
  end

  def block_friend?
    @block_friend ||= DomainBlock.reject_friend?(@account.domain) || DomainBlock.blocked?(@account.domain)
  end

  def block_straight_follow?
    @block_straight_follow ||= DomainBlock.reject_straight_follow?(@account.domain)
  end

  def block_new_follow?
    @block_new_follow ||= DomainBlock.reject_new_follow?(@account.domain)
  end

  def proxy_account?
    (@account.username.downcase.include?('_proxy') ||
     @account.username.downcase.end_with?('proxy') ||
     @account.username.downcase.include?('_bot_') ||
     @account.username.downcase.end_with?('bot') ||
     @account.display_name&.downcase&.include?('proxy') ||
     @account.display_name&.include?('プロキシ') ||
     @account.note&.include?('プロキシ')) &&
      (@account.following_count.zero? || @account.following_count > @account.followers_count) &&
      proxyable_software?
  end

  def proxyable_software?
    info = instance_info
    return false if info.nil?

    %w(misskey calckey firefish meisskey cherrypick).include?(info.software)
  end

  def instance_info
    @instance_info ||= InstanceInfo.find_by(domain: @account.domain)
  end

  def notify_staff_about_pending_friend_server!
    User.those_who_can(:manage_federation).includes(:account).find_each do |u|
      next unless u.allows_pending_friend_server_emails?

      AdminMailer.with(recipient: u.account).new_pending_friend_server(friend).deliver_later
    end
  end
end
