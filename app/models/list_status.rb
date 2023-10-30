# frozen_string_literal: true

# == Schema Information
#
# Table name: list_statuses
#
#  id         :bigint(8)        not null, primary key
#  list_id    :bigint(8)        not null
#  status_id  :bigint(8)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ListStatus < ApplicationRecord
  belongs_to :list
  belongs_to :status

  has_one :notification, as: :activity, dependent: :destroy

  validates :status, uniqueness: { scope: :list }
end
