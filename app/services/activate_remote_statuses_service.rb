# frozen_string_literal: true

class ActivateRemoteStatusesService < BaseService
  include Payloadable
  include FollowHelper

  def call(account)
    @account = account

    PendingStatus.transaction do
      PendingStatus.where(account: account).find_each do |status_info|
        approve_status!(status_info)
      end
    end
  end

  private

  def approve_status!(pending)
    account_id       = pending.account_id
    fetch_account_id = pending.fetch_account_id
    fetch_account    = pending.fetch_account
    uri              = pending.uri
    pending.destroy!

    return if fetch_account.suspended?
    return if ActivityPub::TagManager.instance.uri_to_resource(uri, Status).present?

    ActivityPub::FetchRemoteStatusWorker.perform_async(uri, account_id, fetch_account_id)
  end
end
