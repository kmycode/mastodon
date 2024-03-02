# frozen_string_literal: true

class ActivityPub::ReferencesController < ActivityPub::BaseController
  include SignatureVerification
  include Authorization
  include AccountOwnedConcern

  before_action :require_signature!, if: :authorized_fetch_mode?
  before_action :set_status

  def index
    expires_in 0, public: public_fetch_mode?
    render json: references_collection_presenter, serializer: ActivityPub::CollectionSerializer, adapter: ActivityPub::Adapter, content_type: 'application/activity+json', skip_activities: true
  end

  private

  def pundit_user
    signed_request_account
  end

  def set_status
    @status = @account.statuses.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end

  def load_statuses
    cached_references
  end

  def cached_references
    cache_collection(Status.where(id: results).reorder(:id), Status)
  end

  def results
    @results ||= begin
      references = @status.reference_objects.order(target_status_id: :asc)
      references = references.where('target_status_id > ?', page_params[:min_id]) if page_params[:min_id].present?
      references = references.limit(limit_param(references_limit))
      references.pluck(:target_status_id)
    end
  end

  def references_limit
    StatusReference::REFERENCES_LIMIT
  end

  def pagination_min_id
    results.last
  end

  def records_continue?
    results.size == limit_param(references_limit)
  end

  def references_collection_presenter
    page = ActivityPub::CollectionPresenter.new(
      id: ActivityPub::TagManager.instance.references_uri_for(@status, page_params),
      type: :unordered,
      part_of: ActivityPub::TagManager.instance.references_uri_for(@status),
      items: load_statuses.map(&:uri),
      next: next_page
    )

    return page if page_requested?

    ActivityPub::CollectionPresenter.new(
      type: :unordered,
      id: ActivityPub::TagManager.instance.references_uri_for(@status),
      first: page
    )
  end

  def page_requested?
    truthy_param?(:page)
  end

  def next_page
    return unless records_continue?

    ActivityPub::TagManager.instance.references_uri_for(@status, page_params.merge(min_id: pagination_min_id))
  end

  def page_params
    params_slice(:min_id, :limit).merge(page: true)
  end
end
