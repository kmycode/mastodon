# frozen_string_literal: true

module Admin
  class NgRulesController < BaseController
    before_action :set_ng_rule, only: [:edit, :update, :destroy]

    def index
      authorize :ng_words, :show?

      @ng_rules = ::NgRule.order(id: :asc)
    end

    def new
      authorize :ng_words, :show?

      @ng_rule = ::NgRule.build
    end

    def edit
      authorize :ng_words, :show?
    end

    def create
      authorize :ng_words, :create?

      @ng_rule = ::NgRule.build(resource_params)

      if @ng_rule.save
        redirect_to admin_ng_rules_path
      else
        render :new
      end
    end

    def update
      authorize :ng_words, :create?

      if @ng_rule.update(resource_params)
        redirect_to admin_ng_rules_path
      else
        render :edit
      end
    end

    def destroy
      authorize :ng_words, :create?

      @ng_rule.destroy
      redirect_to admin_ng_rules_path
    end

    private

    def set_ng_rule
      @ng_rule = ::NgRule.find(params[:id])
    end

    def resource_params
      params.require(:ng_rule).permit(:title, :expires_in, :account_domain, :account_username, :account_display_name, :account_note,
                                      :account_field_name, :account_field_value, :account_avatar_state, :account_header_state,
                                      :account_include_local, :status_spoiler_text, :status_text, :status_tag,
                                      :status_sensitive_state, :status_cw_state, :status_media_state, :status_poll_state,
                                      :status_quote_state, :status_reply_state, :status_media_threshold, :status_poll_threshold,
                                      :status_mention_threshold, :status_mention_threshold_stranger_only, :rule_violation_threshold_per_account,
                                      :reaction_type, :reaction_allow_follower, :emoji_reaction_name, :emoji_reaction_origin_domain,
                                      :status_reference_threshold, :account_action, :status_action, :reaction_action,
                                      status_visibility: [], status_searchability: [])
    end
  end
end
