# frozen_string_literal: true

module DtlHelper
  def dtl_enabled?
    ENV.fetch('DTL_ENABLED', 'false') == 'true'
  end

  def dtl_tag_name
    ENV.fetch('DTL_TAG', 'kmyblue')
  end
end
