# frozen_string_literal: true

class Settings::Preferences::BaseController < Settings::BaseController
  def show; end

  def update
    if current_user.update(user_params)
      I18n.locale = current_user.locale
      redirect_to after_update_redirect_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  private

  def after_update_redirect_path
    raise 'Override in controller'
  end

  def user_params
    original_user_params.tap do |params|
      params[:settings_attributes]&.merge!(disabled_visibilities_params[:settings_attributes] || {})
    end
  end

  def original_user_params
    params.require(:user).permit(:locale, :time_zone, :custom_css_text, chosen_languages: [], settings_attributes: UserSettings.keys)
  end

  def disabled_visibilities_params
    params.require(:user).permit(settings_attributes: { enabled_visibilities: [] })
  end
end
