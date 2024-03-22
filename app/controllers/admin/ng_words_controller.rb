# frozen_string_literal: true

module Admin
  class NgWordsController < BaseController
    def show
      authorize :ng_words, :show?

      @admin_settings = Form::AdminSettings.new
    end

    def create
      authorize :ng_words, :create?

      return unless validate

      @admin_settings = Form::AdminSettings.new(settings_params)

      if @admin_settings.save
        flash[:notice] = I18n.t('generic.changes_saved_msg')
        redirect_to after_update_redirect_path
      else
        render :show
      end
    end

    protected

    def validate
      true
    end

    def after_update_redirect_path
      admin_ng_words_path
    end

    private

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end

    def settings_params_test
      params.require(:form_admin_settings)[:ng_words_test]
    end
  end
end
