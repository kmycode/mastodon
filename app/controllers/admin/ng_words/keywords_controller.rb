# frozen_string_literal: true

module Admin
  class NgWords::KeywordsController < NgWordsController
    def show
      super
      @ng_words = ::NgWord.caches.presence || [::NgWord.new]
    end

    protected

    def validate
      begin
        ::NgWord.save_from_raws(settings_params_test)
        return true
      rescue
        flash[:alert] = I18n.t('admin.ng_words.test_error')
        redirect_to after_update_redirect_path
      end

      false
    end

    private

    def after_update_redirect_path
      admin_ng_words_keywords_path
    end
  end
end
