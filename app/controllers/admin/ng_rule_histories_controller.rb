# frozen_string_literal: true

module Admin
  class NgRuleHistoriesController < BaseController
    before_action :set_ng_rule
    before_action :set_histories

    PER_PAGE = 20

    def show
      authorize :ng_words, :show?
    end

    private

    def set_ng_rule
      @ng_rule = ::NgRule.find(params[:id])
    end

    def set_histories
      @histories = NgRuleHistory.where(ng_rule_id: params[:id]).order(id: :desc).page(params[:page]).per(PER_PAGE)
    end
  end
end
