# frozen_string_literal: true

# == Schema Information
#
# Table name: conversations
#
#  id                 :bigint(8)        not null, primary key
#  uri                :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  inbox_url          :string
#  ancestor_status_id :bigint(8)
#

class Conversation < ApplicationRecord
  validates :uri, uniqueness: true, if: :uri?

  has_many :statuses
  has_one :ancestor_status, class_name: 'Status', inverse_of: false

  def local?
    uri.nil?
  end

  def object_type
    :conversation
  end
end
