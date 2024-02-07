# frozen_string_literal: true

module RegistrationLimitationHelper
  def reach_registrations_limit?
    return false unless registrations_in_time?

    (Setting.registrations_limit && Setting.registrations_limit <= user_count_for_registration) ||
      (Setting.registrations_limit_per_day && Setting.registrations_limit_per_day <= today_increase_user_count)
  end

  def user_count_for_registration
    Rails.cache.fetch('registrations:user_count') { User.confirmed.joins(:account).merge(Account.without_suspended).count }
  end

  def today_increase_user_count
    Rails.cache.fetch('registrations:today_increase_user_count') do
      User.confirmed.where('created_at > ?', Time.now.utc.beginning_of_day).joins(:account).merge(Account.without_suspended).count
    end
  end

  def registrations_in_time?
    return true if Setting.registrations_start_hour.negative? || Setting.registrations_end_hour > 24 || Setting.registrations_start_hour >= Setting.registrations_end_hour

    current_hour = Time.now.utc.hour
    Setting.registrations_start_hour <= current_hour && current_hour < Setting.registrations_end_hour
  end

  def reset_registration_limit_caches!
    Rails.cache.delete('registrations:user_count')
    Rails.cache.delete('registrations:today_increase_user_count')
  end
end
