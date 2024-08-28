# frozen_string_literal: true

class CustomCssController < ActionController::Base # rubocop:disable Rails/ApplicationController
  before_action :set_user_roles

  def show
    expires_in 3.minutes, public: true
    render content_type: 'text/css'
  end

  private

  def custom_css_styles
    Setting.custom_css
  end

  def user_custom_css?
    return false if current_user.nil?

    current_user.setting_use_custom_css && current_user.custom_css_text.present?
  end

  def user_custom_css
    current_user.custom_css_text
  end
  helper_method :custom_css_styles, :user_custom_css?, :user_custom_css

  def set_user_roles
    @user_roles = UserRole.providing_styles
  end
end
