# frozen_string_literal: true

module RegistrationRejectionHelper
  def match_rejection_registration_pattern?(email, username)
    rejection_email_pattern?(email) || rejection_username_pattern?(username)
  end

  def rejection_email_pattern?(email)
    TextPattern.detect_keyword?(email, Setting.registration_reject_email_pattern)
  end

  def rejection_username_pattern?(username)
    TextPattern.detect_keyword?(username, Setting.registration_reject_username_pattern)
  end
end
