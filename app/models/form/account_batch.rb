# frozen_string_literal: true

class Form::AccountBatch
  include ActiveModel::Model
  include Authorization
  include AccountableConcern
  include Payloadable

  attr_accessor :account_ids, :action, :current_account,
                :select_all_matching, :query

  def save
    case action
    when 'follow'
      follow!
    when 'unfollow'
      unfollow!
    when 'remove_from_followers'
      remove_from_followers!
    when 'remove_domains_from_followers'
      remove_domains_from_followers!
    when 'approve'
      approve!
    when 'reject'
      reject!
    when 'approve_remote'
      approve_remote!
    when 'approve_remote_domain'
      approve_remote_domain!
    when 'reject_remote'
      reject_remote!
    when 'suppress_follow_recommendation'
      suppress_follow_recommendation!
    when 'unsuppress_follow_recommendation'
      unsuppress_follow_recommendation!
    when 'suspend'
      suspend!
    end
  end

  private

  def follow!
    error = nil

    accounts.each do |target_account|
      FollowService.new.call(current_account, target_account)
    rescue Mastodon::NotPermittedError, ActiveRecord::RecordNotFound => e
      error ||= e
    end

    raise error if error.present?
  end

  def unfollow!
    accounts.each do |target_account|
      UnfollowService.new.call(current_account, target_account)
    end
  end

  def remove_from_followers!
    RemoveFromFollowersService.new.call(current_account, account_ids)
  end

  def remove_domains_from_followers!
    RemoveDomainsFromFollowersService.new.call(current_account, account_domains)
  end

  def account_domains
    accounts.group(:domain).pluck(:domain).compact
  end

  def accounts
    if select_all_matching?
      query
    else
      Account.where(id: account_ids)
    end
  end

  def approve!
    accounts.includes(:user).find_each do |account|
      approve_account(account)
    end
  end

  def reject!
    accounts.includes(:user).find_each do |account|
      reject_account(account)
    end
  end

  def approve_remote!
    accounts.find_each do |account|
      approve_remote_account(account)
    end
  end

  def approve_remote_domain!
    domains = accounts.group_by(&:domain).pluck(0)
    if (Setting.permit_new_account_domains || []).compact_blank.present?
      list = ((Setting.permit_new_account_domains || []) + domains).compact_blank.uniq.join("\n")
      Form::AdminSettings.new(permit_new_account_domains: list).save
    end
    Account.where(domain: domains, remote_pending: true).find_each do |account|
      approve_remote_account(account)
    end
  end

  def reject_remote!
    accounts.find_each do |account|
      reject_remote_account(account)
    end
  end

  def suspend!
    accounts.find_each do |account|
      if account.user_pending?
        reject_account(account)
      else
        suspend_account(account)
      end
    end
  end

  def suppress_follow_recommendation!
    authorize(:follow_recommendation, :suppress?)

    accounts.find_each do |account|
      FollowRecommendationSuppression.create(account: account)
    end
  end

  def unsuppress_follow_recommendation!
    authorize(:follow_recommendation, :unsuppress?)

    FollowRecommendationSuppression.where(account_id: account_ids).destroy_all
  end

  def reject_account(account)
    authorize(account.user, :reject?)
    log_action(:reject, account.user)
    account.suspend!(origin: :local)
    AccountDeletionWorker.perform_async(account.id, { 'reserve_username' => false })
  end

  def reject_remote_account(account)
    authorize(account, :reject_remote?)
    log_action(:reject_remote, account)
    account.reject_remote!
    process_suspend(account)
  end

  def suspend_account(account)
    authorize(account, :suspend?)
    log_action(:suspend, account)
    account.suspend!(origin: :local)
    process_suspend(account)
  end

  def process_suspend(account)
    account.strikes.create!(
      account: current_account,
      action: :suspend
    )

    Admin::SuspensionWorker.perform_async(account.id)

    # Suspending a single account closes their associated reports, so
    # mass-suspending would be consistent.
    Report.where(target_account: account).unresolved.find_each do |report|
      authorize(report, :update?)
      log_action(:resolve, report)
      report.resolve!(current_account)
    rescue Mastodon::NotPermittedError
      # This should not happen, but just in case, do not fail early
    end
  end

  def approve_account(account)
    authorize(account.user, :approve?)
    log_action(:approve, account.user)
    account.user.approve!
  end

  def approve_remote_account(account)
    authorize(account, :approve_remote?)
    log_action(:approve_remote, account)
    account.approve_remote!
  end

  def select_all_matching?
    select_all_matching == '1'
  end
end
