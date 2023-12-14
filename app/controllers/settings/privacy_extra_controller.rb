# frozen_string_literal: true

class Settings::PrivacyExtraController < Settings::BaseController
  before_action :set_account

  def show; end

  def update
    if UpdateAccountService.new.call(@account, account_params.except(:settings))
      current_user.update!(settings_attributes: account_params[:settings])
      ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
      redirect_to settings_privacy_extra_path, notice: I18n.t('generic.changes_saved_msg')
    else
      render :show
    end
  end

  private

  def account_params
    params.require(:account).permit(:subscription_policy, settings: UserSettings.keys)
  end

  def set_account
    @account = current_account
  end
end
