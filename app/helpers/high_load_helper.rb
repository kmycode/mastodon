# frozen_string_literal: true

module HighLoadHelper
  def allow_high_load?
    ENV.fetch('ALLOW_HIGH_LOAD', 'true') == 'true'
  end
  module_function :allow_high_load?
end
