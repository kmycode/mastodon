# frozen_string_literal: true

# == Schema Information
#
# Table name: ng_rule_histories
#
#  id         :bigint(8)        not null, primary key
#  ng_rule_id :bigint(8)        not null
#  account_id :bigint(8)        not null
#  text       :string
#  uri        :string
#  reason     :string           not null
#  skip       :boolean          default(FALSE), not null
#  skip_count :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class NgRuleHistory < ApplicationRecord
  belongs_to :ng_rule
  belongs_to :account
end
