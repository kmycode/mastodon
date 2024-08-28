# frozen_string_literal: true

class Settings::Preferences::CustomCssController < Settings::Preferences::BaseController
  private

  def after_update_redirect_path
    settings_preferences_custom_css_path
  end
end
