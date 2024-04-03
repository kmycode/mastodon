# frozen_string_literal: true

module Admin
  class SpecialDomainsController < BaseController
    def show
      authorize :instance, :show?

      @admin_settings = Form::AdminSettings.new
    end

    def create
      authorize :instance, :destroy?

      @admin_settings = Form::AdminSettings.new(settings_params)

      if @admin_settings.save
        flash[:notice] = I18n.t('generic.changes_saved_msg')
        redirect_to after_update_redirect_path
      else
        render :show
      end
    end

    private

    def after_update_redirect_path
      admin_special_domains_path
    end

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end
  end
end
