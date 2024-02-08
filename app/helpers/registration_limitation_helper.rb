# frozen_string_literal: true

module RegistrationLimitationHelper
  def reach_registrations_limit?
    return true unless registrations_in_time?

    (Setting.registrations_limit && Setting.registrations_limit <= user_count_for_registration) ||
      (Setting.registrations_limit_per_day && Setting.registrations_limit_per_day <= today_increase_user_count)
  end

  def user_count_for_registration
    Rails.cache.fetch('registrations:user_count') { User.confirmed.joins(:account).merge(Account.without_suspended).count }
  end

  def today_increase_user_count
    today_date = Time.now.utc.beginning_of_day.to_i
    count = 0

    if Rails.cache.fetch('registrations:today_date') { today_date } == today_date
      count = Rails.cache.fetch('registrations:today_increase_user_count') { today_increase_user_count_value }
    else
      count = today_increase_user_count_value
      Rails.cache.write('registrations:today_date', today_date)
      Rails.cache.write('registrations:today_increase_user_count', count)
    end

    count
  end

  def today_increase_user_count_value
    User.confirmed.where('users.created_at >= ?', Time.now.utc.beginning_of_day).joins(:account).merge(Account.without_suspended).count
  end

  def registrations_in_time?
    start_hour = Setting.registrations_start_hour || 0
    end_hour = Setting.registrations_end_hour || 24
    return true if start_hour.negative? || end_hour > 24 || start_hour >= end_hour

    current_hour = Time.now.utc.hour
    start_hour <= current_hour && current_hour < end_hour
  end

  def reset_registration_limit_caches!
    Rails.cache.delete('registrations:user_count')
    Rails.cache.delete('registrations:today_increase_user_count')
  end
end
