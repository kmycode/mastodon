# frozen_string_literal: true

class UserCustomCssController < ActionController::Base # rubocop:disable Rails/ApplicationController
  before_action :authenticate_user!

  def show
    render content_type: 'text/css'
  end

  private

  def user_custom_css
    current_user.custom_css_text
  end
  helper_method :user_custom_css
end
