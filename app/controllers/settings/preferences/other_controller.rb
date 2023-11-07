# frozen_string_literal: true

class Settings::Preferences::OtherController < Settings::Preferences::BaseController
  include DtlHelper

  def show
    @dtl_enabled = dtl_enabled?
    @dtl_tag = dtl_tag_name
  end

  private

  def after_update_redirect_path
    settings_preferences_other_path
  end
end
