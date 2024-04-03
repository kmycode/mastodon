# frozen_string_literal: true

module Admin
  class NgWords::WhiteListController < NgWordsController
    def show
      super
      @white_list_domains = SpecifiedDomain.white_list_domain_caches.presence || [SpecifiedDomain.new]
    end

    protected

    def validate
      begin
        SpecifiedDomain.save_from_raws_as_white_list(settings_params_list)
        return true
      rescue
        flash[:alert] = I18n.t('admin.ng_words.save_error')
        redirect_to after_update_redirect_path
      end

      false
    end

    def after_update_redirect_path
      admin_ng_words_white_list_path
    end

    private

    def settings_params_list
      params.require(:form_admin_settings)[:specified_domains]
    end
  end
end
