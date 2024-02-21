# frozen_string_literal: true

# == Schema Information
#
# Table name: ng_rules
#
#  id                                   :bigint(8)        not null, primary key
#  title                                :string           default(""), not null
#  available                            :boolean          default(TRUE), not null
#  record_history_also_local            :boolean          default(TRUE), not null
#  account_domain                       :string           default(""), not null
#  account_username                     :string           default(""), not null
#  account_display_name                 :string           default(""), not null
#  account_note                         :string           default(""), not null
#  account_field_name                   :string           default(""), not null
#  account_field_value                  :string           default(""), not null
#  account_avatar_state                 :integer          default("optional"), not null
#  account_header_state                 :integer          default("optional"), not null
#  account_include_local                :boolean          default(TRUE), not null
#  status_spoiler_text                  :string           default(""), not null
#  status_text                          :string           default(""), not null
#  status_tag                           :string           default(""), not null
#  status_visibility                    :string           default([]), not null, is an Array
#  status_searchability                 :string           default([]), not null, is an Array
#  status_media_state                   :integer          default("optional"), not null
#  status_sensitive_state               :integer          default("optional"), not null
#  status_cw_state                      :integer          default("optional"), not null
#  status_poll_state                    :integer          default("optional"), not null
#  status_quote_state                   :integer          default("optional"), not null
#  status_reply_state                   :integer          default("optional"), not null
#  status_tag_threshold                 :integer          default(-1), not null
#  status_media_threshold               :integer          default(-1), not null
#  status_poll_threshold                :integer          default(-1), not null
#  status_mention_threshold             :integer          default(-1), not null
#  status_mention_allow_follower        :boolean          default(TRUE), not null
#  status_reference_threshold           :integer          default(-1), not null
#  reaction_type                        :string           default([]), not null, is an Array
#  reaction_allow_follower              :boolean          default(TRUE), not null
#  emoji_reaction_name                  :string           default(""), not null
#  emoji_reaction_origin_domain         :string           default(""), not null
#  rule_violation_threshold_per_account :integer          default(0), not null
#  account_action                       :integer          default("nothing"), not null
#  status_action                        :integer          default("nothing"), not null
#  reaction_action                      :integer          default("nothing"), not null
#  expires_at                           :datetime
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#
class NgRule < ApplicationRecord
  include Expireable
  include Redisable

  has_many :histories, class_name: 'NgRuleHistory', inverse_of: :ng_rule, dependent: :destroy

  enum :account_avatar_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :account_avatar
  enum :account_header_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :account_header
  enum :status_sensitive_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_sensitive
  enum :status_cw_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_cw
  enum :status_quote_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_quote
  enum :status_reply_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_reply
  enum :status_media_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_media
  enum :status_poll_state, { optional: 0, needed: 1, no_needed: 2 }, prefix: :status_poll
  enum :account_action, { nothing: 0, silence: 1, suspend: 2 }, prefix: :account_action
  enum :status_action, { nothing: 0, reject: 1 }, prefix: :status_action
  enum :reaction_action, { nothing: 0, reject: 1 }, prefix: :reaction_action

  scope :enabled, -> { where(available: true) }

  before_validation :clean_up_arrays
  before_save :prepare_cache_invalidation!
  before_destroy :prepare_cache_invalidation!
  after_commit :invalidate_cache!

  def self.cached_rules
    active_rules = Rails.cache.fetch('ng_rules') do
      NgRule.enabled.to_a
    end

    active_rules.reject { |ng_rule, _| ng_rule.expired? }
  end

  def expires_in
    return @expires_in if defined?(@expires_in)
    return nil if expires_at.nil?

    [30.minutes, 1.hour, 6.hours, 12.hours, 1.day, 1.week, 2.weeks, 1.month, 3.months].find { |expires_in| expires_in.from_now >= expires_at }
  end

  def clean_up_arrays
    self.status_visibility    = Array(status_visibility).map(&:strip).filter_map(&:presence)
    self.status_searchability = Array(status_searchability).map(&:strip).filter_map(&:presence)
    self.reaction_type        = Array(reaction_type).map(&:strip).filter_map(&:presence)
  end

  def prepare_cache_invalidation!
    @should_invalidate_cache = true
  end

  def invalidate_cache!
    return unless @should_invalidate_cache

    @should_invalidate_cache = false

    Rails.cache.delete('ng_rules')
  end
end
