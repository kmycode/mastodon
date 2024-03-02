# frozen_string_literal: true

# == Schema Information
#
# Table name: pending_follow_requests
#
#  id                :bigint(8)        not null, primary key
#  account_id        :bigint(8)        not null
#  target_account_id :bigint(8)        not null
#  uri               :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class PendingFollowRequest < ApplicationRecord
  belongs_to :account
  belongs_to :target_account, class_name: 'Account'

  validates :account_id, uniqueness: { scope: :target_account_id }
end
