# frozen_string_literal: true

class ActivateFollowRequestsService < BaseService
  include Payloadable
  include FollowHelper

  def call(account)
    @account = account

    PendingFollowRequest.transaction do
      PendingFollowRequest.where(account: account).find_each do |follow_request|
        approve_follow!(follow_request)
      end
    end
  end

  private

  def approve_follow!(pending)
    follow_request = FollowRequest.create!(account: @account, target_account: pending.target_account, uri: pending.uri)
    pending.destroy!

    target_account = follow_request.target_account

    if request_pending_follow?(@account, target_account)
      LocalNotificationWorker.perform_async(target_account.id, follow_request.id, 'FollowRequest', 'follow_request')
    else
      AuthorizeFollowService.new.call(@account, target_account)
      LocalNotificationWorker.perform_async(target_account.id, ::Follow.find_by(account: @account, target_account: target_account).id, 'Follow', 'follow')
    end
  end
end
