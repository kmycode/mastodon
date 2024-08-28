# frozen_string_literal: true

#
# == Schema Information
#
# Table name: custom_csses
#
#  id         :bigint(8)        not null, primary key
#  user_id    :bigint(8)        not null
#  css        :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class CustomCss < ApplicationRecord
  belongs_to :user
end
