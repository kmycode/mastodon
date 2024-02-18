# frozen_string_literal: true

class EnableFollowRequestsWorker
  include Sidekiq::Worker

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return true if account.nil?
    return true if account.suspended?

    EnableFollowRequestsService.new.call(account)
  end
end
