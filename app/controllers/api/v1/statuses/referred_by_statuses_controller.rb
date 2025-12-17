# frozen_string_literal: true

class Api::V1::Statuses::ReferredByStatusesController < Api::BaseController
  include Authorization

  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_status
  after_action :insert_pagination_headers

  def index
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer,
           relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id),
           emoji_reaction_permitted_account_ids: EmojiReactionAccountsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def load_statuses
    cached_references
  end

  def cached_references
    results
  end

  def results
    return @results if @results

    account     = current_user&.account
    statuses    = Status.where(id: @status.referenced_by_status_objects.select(:status_id))
    statuses.map(&:account_id).uniq
    statuses.filter_map(&:account_domain).uniq

    statuses = preload_collection_paginated_by_id(
      statuses,
      Status,
      limit_param(DEFAULT_STATUSES_LIMIT),
      params_slice(:max_id, :since_id, :min_id)
    )

    @results = statuses.filter { |status| !StatusFilter.new(status, account).filtered? }
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def next_path
    api_v1_status_referred_by_index_url pagination_params(max_id: pagination_max_id) if records_continue?
  end

  def prev_path
    api_v1_status_referred_by_index_url pagination_params(min_id: pagination_since_id) unless results.empty?
  end

  def pagination_max_id
    results.last.id
  end

  def pagination_since_id
    results.first.id
  end

  def records_continue?
    results.size == limit_param(DEFAULT_STATUSES_LIMIT)
  end

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end
end
