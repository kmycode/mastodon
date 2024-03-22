# frozen_string_literal: true

module Admin
  class NgWords::SettingsController < NgWordsController
    protected

    def after_update_redirect_path
      admin_ng_words_settings_path
    end
  end
end
