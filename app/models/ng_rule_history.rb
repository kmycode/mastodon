# frozen_string_literal: true

# == Schema Information
#
# Table name: ng_rule_histories
#
#  id            :bigint(8)        not null, primary key
#  ng_rule_id    :bigint(8)        not null
#  account_id    :bigint(8)
#  text          :string
#  uri           :string
#  reason        :integer          not null
#  reason_action :integer          not null
#  local         :boolean          default(TRUE), not null
#  hidden        :boolean          default(FALSE), not null
#  data          :jsonb
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class NgRuleHistory < ApplicationRecord
  enum :reason, { account: 0, status: 1, reaction: 2 }, prefix: :reason
  enum :reason_action, {
    account_create: 0,
    status_create: 10,
    status_edit: 11,
    reaction_favourite: 20,
    reaction_emoji_reaction: 21,
    reaction_follow: 22,
    reaction_reblog: 23,
    reaction_vote: 24,
  }, prefix: :reason_action

  belongs_to :ng_rule
  belongs_to :account
end
