# frozen_string_literal: true

module Admin
  class NgWordsController < BaseController
    def show
      authorize :ng_words, :show?

      @admin_settings = Form::AdminSettings.new
    end

    def create
      authorize :ng_words, :create?

      begin
        test_words
      rescue
        flash[:alert] = I18n.t('admin.ng_words.test_error')
        redirect_to after_update_redirect_path
        return
      end

      @admin_settings = Form::AdminSettings.new(settings_params)

      if @admin_settings.save
        flash[:notice] = I18n.t('generic.changes_saved_msg')
        redirect_to after_update_redirect_path
      else
        render :show
      end
    end

    private

    def test_words
      ng_words = "#{settings_params['ng_words']}\n#{settings_params['ng_words_for_stranger_mention']}".split(/\r\n|\r|\n/).filter(&:present?)
      Admin::NgWord.reject_with_custom_words?('Sample text', ng_words)
    end

    def after_update_redirect_path
      admin_ng_words_path
    end

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end
  end
end
