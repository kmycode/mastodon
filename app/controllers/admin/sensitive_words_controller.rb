# frozen_string_literal: true

module Admin
  class SensitiveWordsController < BaseController
    def show
      authorize :sensitive_words, :show?

      @admin_settings = Form::AdminSettings.new
      @sensitive_words = ::SensitiveWord.caches

      @sensitive_words = [
        ::SensitiveWord.new(id: 1, regexp: true),
        ::SensitiveWord.new(id: 2, remote: true),
        ::SensitiveWord.new(id: 3, regexp: true),
        ::SensitiveWord.new(id: 4, remote: true),
      ]
    end

    def create
      authorize :sensitive_words, :create?

      begin
        test_words
      rescue
        flash[:alert] = I18n.t('admin.ng_words.test_error')
        redirect_to after_update_redirect_path
        return
      end

      @admin_settings = Form::AdminSettings.new(settings_params)

      if @admin_settings.save && ::SensitiveWord.save_from_raws(settings_params_test)
        flash[:notice] = I18n.t('generic.changes_saved_msg')
        redirect_to after_update_redirect_path
      else
        render :index
      end
    end

    private

    def test_words
      sensitive_words = settings_params['sensitive_words'].split(/\r\n|\r|\n/)
      sensitive_words_for_full = settings_params['sensitive_words_for_full'].split(/\r\n|\r|\n/)
      sensitive_words_all = settings_params['sensitive_words_all'].split(/\r\n|\r|\n/)
      sensitive_words_all_for_full = settings_params['sensitive_words_all_for_full'].split(/\r\n|\r|\n/)
      Admin::NgWord.reject_with_custom_words?('Sample text', sensitive_words + sensitive_words_for_full + sensitive_words_all + sensitive_words_all_for_full)
    end

    def after_update_redirect_path
      admin_sensitive_words_path
    end

    def settings_params
      params.require(:form_admin_settings).permit(*Form::AdminSettings::KEYS)
    end

    def settings_params_test
      params.require(:form_admin_settings)[:sensitive_words_test]
    end
  end
end
