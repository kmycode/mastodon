# frozen_string_literal: true

class StatusesController < ApplicationController
  include WebAppControllerConcern
  include SignatureAuthentication
  include Authorization
  include AccountOwnedConcern

  vary_by -> { public_fetch_mode? ? 'Accept, Accept-Language, Cookie' : 'Accept, Accept-Language, Cookie, Signature' }

  before_action :require_account_signature!, only: [:show, :activity], if: -> { request.format == :json && authorized_fetch_mode? }
  before_action :set_status
  before_action :redirect_to_original, only: :show
  before_action :set_body_classes, only: :embed

  after_action :set_link_headers

  skip_around_action :set_locale, if: -> { request.format == :json }
  skip_before_action :require_functional!, only: [:show, :embed], unless: :limited_federation_mode?

  content_security_policy only: :embed do |policy|
    policy.frame_ancestors(false)
  end

  def show
    respond_to do |format|
      format.html do
        expires_in 10.seconds, public: true if current_account.nil?
      end

      format.json do
        expires_in 3.minutes, public: true if @status.distributable? && public_fetch_mode? && !misskey_software? && !@status.expires?
        render_with_cache json: @status, content_type: 'application/activity+json', serializer: status_activity_serializer, adapter: ActivityPub::Adapter, cancel_cache: misskey_software?
      end
    end
  end

  def activity
    expires_in 3.minutes, public: @status.distributable? && public_fetch_mode? && !misskey_software?
    render_with_cache json: ActivityPub::ActivityPresenter.from_status(@status, for_misskey: misskey_software?), content_type: 'application/activity+json', serializer: ActivityPub::ActivitySerializer, adapter: ActivityPub::Adapter, cancel_cache: misskey_software?
  end

  def embed
    return not_found if @status.hidden? || @status.reblog?

    expires_in 180, public: true
    response.headers.delete('X-Frame-Options')

    render layout: 'embedded'
  end

  private

  def set_body_classes
    @body_classes = 'with-modals'
  end

  def set_link_headers
    response.headers['Link'] = LinkHeader.new([[ActivityPub::TagManager.instance.uri_for(@status), [%w(rel alternate), %w(type application/activity+json)]]])
  end

  def set_status
    @status = @account.statuses.find(params[:id])

    if request.authorization.present? && request.authorization.match(/^Bearer /i)
      raise Mastodon::NotPermittedError unless @status.capability_tokens.find_by(token: request.authorization.gsub(/^Bearer /i, ''))
    elsif request.format == :json && @status.expires?
      raise Mastodon::NotPermittedError unless StatusPolicy.new(signed_request_account, @status).show_activity?
    else
      authorize @status, :show?
    end
  rescue Mastodon::NotPermittedError
    not_found
  end

  def misskey_software?
    return @misskey_software if defined?(@misskey_software)

    @misskey_software = false

    return false if !@status.local? || signed_request_account&.domain.blank?

    info = InstanceInfo.find_by(domain: signed_request_account.domain)
    return false if info.nil?

    @misskey_software = %w(misskey calckey cherrypick sharkey).include?(info.software) &&
                        ((@status.public_unlisted_visibility? && @status.account.user&.setting_reject_public_unlisted_subscription) ||
                         (@status.unlisted_visibility? && @status.account.user&.setting_reject_unlisted_subscription))
  end

  def status_activity_serializer
    if misskey_software?
      ActivityPub::NoteForMisskeySerializer
    else
      ActivityPub::NoteSerializer
    end
  end

  def redirect_to_original
    redirect_to(ActivityPub::TagManager.instance.url_for(@status.reblog), allow_other_host: true) if @status.reblog?
  end
end
