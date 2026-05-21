# frozen_string_literal: true

class Api::V1::Statuses::ContextsController < Api::BaseController
  include Authorization
  include AsyncRefreshesConcern

  before_action -> { authorize_if_got_token! :read, :'read:statuses' }
  before_action :set_status

  # This API was originally unlimited, pagination cannot be introduced without
  # breaking backwards-compatibility. Arbitrarily high number to cover most
  # conversations as quasi-unlimited, it would be too much work to render more
  # than this anyway
  CONTEXT_LIMIT = 4_096

  # This remains expensive and we don't want to show everything to logged-out users
  ANCESTORS_LIMIT         = 40
  DESCENDANTS_LIMIT       = 60
  DESCENDANTS_DEPTH_LIMIT = 20
  REFERENCES_LIMIT        = 20

  def show
    cache_if_unauthenticated!

    ancestors_limit         = CONTEXT_LIMIT
    descendants_limit       = CONTEXT_LIMIT
    descendants_depth_limit = nil
    references_limit        = CONTEXT_LIMIT

    if current_account.nil?
      ancestors_limit         = ANCESTORS_LIMIT
      descendants_limit       = DESCENDANTS_LIMIT
      descendants_depth_limit = DESCENDANTS_DEPTH_LIMIT
      references_limit        = REFERENCES_LIMIT
    end

    ancestors_results   = @status.in_reply_to_id.nil? ? [] : @status.ancestors(ancestors_limit, current_account)
    descendants_results = @status.descendants(descendants_limit, current_account, descendants_depth_limit)
    references_results  = @status.readable_references(references_limit, current_account)
    loaded_ancestors    = preload_collection(ancestors_results, Status)
    loaded_descendants  = preload_collection(descendants_results, Status)
    loaded_references   = preload_collection(references_results, Status)

    if params[:with_reference]
      loaded_references.reject! { |status| loaded_ancestors.any? { |ancestor| ancestor.id == status.id } }
    else
      loaded_ancestors = (loaded_ancestors + loaded_references).uniq(&:id)
      loaded_references = []
    end

    @context = Context.new(ancestors: loaded_ancestors, descendants: loaded_descendants, references: loaded_references)
    statuses = [@status] + @context.ancestors + @context.descendants + @context.references

    refresh_key = "context:#{@status.id}:refresh"
    async_refresh = AsyncRefresh.new(refresh_key)

    if async_refresh.running?
      add_async_refresh_header(async_refresh)
    elsif !current_account.nil? && @status.should_fetch_replies?
      add_async_refresh_header(AsyncRefresh.create(refresh_key, count_results: true))

      WorkerBatch.new.within do |batch|
        batch.connect(refresh_key, threshold: 1.0)
        ActivityPub::FetchAllRepliesWorker.perform_async(@status.id, { 'batch_id' => batch.id })
      end
    end

    render json: @context, serializer: REST::ContextSerializer, relationships: StatusRelationshipsPresenter.new(statuses, current_user&.account_id)
  end

  private

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue ActiveRecord::RecordNotFound, Mastodon::NotPermittedError
    not_found
  end
end
