# frozen_string_literal: true

class ActivateRemoteAccountWorker
  include Sidekiq::Worker

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return true if account.nil?
    return true if account.suspended?

    ActivateFollowRequestsService.new.call(account)
    ActivateRemoteStatusesService.new.call(account)
  end
end
