# frozen_string_literal: true

class UpdateStatusExpirationService < BaseService
  SCAN_EXPIRATION_RE = /#exp((\d{1,4}\.\d{1,2}|\d{1,4}))(d|h|m|s)/

  def call(status)
    existing_expiration = ScheduledExpirationStatus.find_by(status: status)
    existing_expiration&.destroy!

    expiration = status.text.scan(SCAN_EXPIRATION_RE).first
    return unless expiration

    expiration_num = expiration[1].to_f
    expiration_option = expiration[2]
    base_time = status.created_at || Time.now.utc

    # rubocop:disable-next Style/CaseLikeIf
    due = if expiration_option == 'd'
            expiration_num.days
          elsif expiration_option == 'h'
            expiration_num.hours
          else
            expiration_option == 's' ? expiration_num.seconds : expiration_num.minutes
          end

    expired_at = base_time + due
    expired_status = ScheduledExpirationStatus.create!(account: status.account, status: status, scheduled_at: expired_at)

    RemoveExpiredStatusWorker.perform_at(expired_at, expired_status.id) if due < ScheduledStatus::MINIMUM_OFFSET
  end
end
