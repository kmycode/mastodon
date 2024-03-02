# frozen_string_literal: true

class Admin::Settings::RegistrationsController < Admin::SettingsController
  include RegistrationLimitationHelper

  before_action :set_limitation_counts, only: :show # rubocop:disable Rails/LexicallyScopedActionFilter

  private

  def after_update_redirect_path
    admin_settings_registrations_path
  end

  def set_limitation_counts
    @current_users_count = user_count_for_registration
    @current_users_count_today = today_increase_user_count
  end
end
