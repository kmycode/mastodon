# frozen_string_literal: true

class ActivityPub::Activity::Follow < ActivityPub::Activity
  include Payloadable
  include FollowHelper
  include NgRuleHelper

  def perform
    return request_follow_for_friend if friend_follow?

    target_account = account_from_uri(object_uri)

    return if target_account.nil? || !target_account.local? || delete_arrived_first?(@json['id'])
    return unless check_invalid_reaction_for_ng_rule! @account, uri: @json['id'], reaction_type: 'follow', recipient: target_account

    # Update id of already-existing follow requests
    existing_follow_request = ::FollowRequest.find_by(account: @account, target_account: target_account) || PendingFollowRequest.find_by(account: @account, target_account: target_account)
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

    if @account.suspended? && @account.remote_pending?
      PendingFollowRequest.create!(account: @account, target_account: target_account, uri: @json['id'])
      return
    elsif @account.suspended?
      return
    end

    follow_request = FollowRequest.create!(account: @account, target_account: target_account, uri: @json['id'])

    if request_pending_follow?(@account, target_account)
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
      already_accepted = friend.accepted?
      friend.update!(passive_state: :pending, active_state: :idle, passive_follow_activity_id: @json['id'])
    else
      @friend = FriendDomain.new(domain: @account.domain, passive_state: :pending, passive_follow_activity_id: @json['id'])
      @friend.inbox_url = @json['inboxUrl'].presence || @friend.default_inbox_url
      @friend.save!
    end

    if already_accepted || Setting.unlocked_friend
      friend.accept!

      # Notify for admin even if unlocked
      notify_staff_about_pending_friend_server! unless already_accepted
    else
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

  def block_new_follow?
    @block_new_follow ||= DomainBlock.reject_new_follow?(@account.domain)
  end

  def notify_staff_about_pending_friend_server!
    User.those_who_can(:manage_federation).includes(:account).find_each do |u|
      next unless u.allows_pending_friend_server_emails?

      AdminMailer.with(recipient: u.account).new_pending_friend_server(friend).deliver_later
    end
  end
end
