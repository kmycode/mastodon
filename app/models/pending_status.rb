# frozen_string_literal: true

# == Schema Information
#
# Table name: pending_statuses
#
#  id               :bigint(8)        not null, primary key
#  account_id       :bigint(8)        not null
#  fetch_account_id :bigint(8)        not null
#  uri              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class PendingStatus < ApplicationRecord
  belongs_to :account
  belongs_to :fetch_account, class_name: 'Account'
end
