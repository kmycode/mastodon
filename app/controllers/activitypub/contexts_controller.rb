# frozen_string_literal: true

class ActivityPub::ContextsController < ActivityPub::BaseController
  include SignatureVerification

  vary_by -> { 'Signature' if authorized_fetch_mode? }

  before_action :set_context

  def show
    expires_in 3.minutes, public: true
    render json: @context,
           serializer: ActivityPub::ContextSerializer,
           adapter: ActivityPub::Adapter,
           content_type: 'application/activity+json'
  end

  private

  def set_context
    @context = Conversation.find(params[:id])
  end
end
