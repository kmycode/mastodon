# frozen_string_literal: true

class Api::V1::Accounts::ExcludeAntennasController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:lists' }
  before_action :require_user!
  before_action :set_account

  def index
    @antennas = @account.suspended? ? [] : current_account.antennas.where("exclude_accounts @> '#{@account.id}'")
    render json: @antennas, each_serializer: REST::AntennaSerializer
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end
end
