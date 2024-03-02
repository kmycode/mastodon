# frozen_string_literal: true

class Settings::ProfilesController < Settings::BaseController
  before_action :set_account

  def show
    @account.build_fields
  end

  def update
    if UpdateAccountService.new.call(@account, account_params)
      ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
      redirect_to settings_profile_path, notice: I18n.t('generic.changes_saved_msg')
    else
      @account.build_fields
      render :show
    end
  end

  private

  def account_params
    # params.require(:account).permit(:display_name, :note, :bio_markdown, :avatar, :header, :locked, :my_actor_type, :searchability, :dissubscribable, :discoverable, :discoverable_local, :hide_collections, fields_attributes: [:name, :value])
    params.require(:account).permit(:display_name, :note, :bio_markdown, :avatar, :header, :bot, :my_actor_type, :dissubscribable, fields_attributes: [:name, :value])
  end

  def set_account
    @account = current_account
  end
end
