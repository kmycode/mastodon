# frozen_string_literal: true

module Admin
  class NgwordHistoriesController < BaseController
    before_action :set_histories

    PER_PAGE = 20

    def index
      authorize :ng_words, :show?
    end

    private

    def set_histories
      @histories = NgwordHistory.order(id: :desc).page(params[:page]).per(PER_PAGE)
    end
  end
end
