# frozen_string_literal: true

module Admin
  class NgWords::WhiteListController < NgWordsController
    protected

    def after_update_redirect_path
      admin_ng_words_white_list_path
    end
  end
end
