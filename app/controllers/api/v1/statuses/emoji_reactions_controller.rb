# frozen_string_literal: true

class Api::V1::Statuses::EmojiReactionsController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:favourites' }
  before_action :require_user!
  before_action :set_status, only: %i(create update)
  before_action :set_status_without_authorize, only: [:destroy]

  def create
    create_private(params[:emoji] || params[:id])
  end

  # For compatible with Fedibird API
  def update
    create_private(params[:id])
  end

  def destroy
    emoji = params[:emoji] || params[:id]

    if emoji
      shortcode, domain = emoji.split('@')
      emoji_reaction = EmojiReaction.where(account_id: current_account.id).where(status_id: @status.id).where(name: shortcode)
                                    .find { |reaction| domain == '' ? reaction.custom_emoji.nil? : reaction.custom_emoji&.domain == domain }

      authorize @status, :show? if emoji_reaction.nil?

      UnEmojiReactService.new.call(current_account, @status, emoji_reaction) if emoji_reaction.present?
    else
      authorize @status, :show?
    end

    render json: @status, serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(
      [@status], current_account.id
    )
  rescue Mastodon::NotPermittedError
    not_found
  end

  private

  def create_private(emoji)
    count = EmojiReaction.where(account: current_account, status: @status).count
    raise Mastodon::ValidationError, I18n.t('reactions.errors.limit_reached') if count >= EmojiReaction::EMOJI_REACTION_PER_ACCOUNT_LIMIT
    raise Mastodon::ValidationError, I18n.t('reactions.errors.disabled') unless Setting.enable_emoji_reaction

    EmojiReactService.new.call(current_account, @status, emoji)
    render json: @status, serializer: REST::StatusSerializer
  end

  def set_status
    set_status_without_authorize
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end

  def set_status_without_authorize
    @status = Status.find(params[:status_id])
  end
end
