# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_blocks
#
#  id                             :bigint(8)        not null, primary key
#  domain                         :string           default(""), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  severity                       :integer          default("silence")
#  reject_media                   :boolean          default(FALSE), not null
#  reject_reports                 :boolean          default(FALSE), not null
#  private_comment                :text
#  public_comment                 :text
#  obfuscate                      :boolean          default(FALSE), not null
#  reject_favourite               :boolean          default(FALSE), not null
#  reject_reply                   :boolean          default(FALSE), not null
#  reject_send_sensitive          :boolean          default(FALSE), not null
#  reject_hashtag                 :boolean          default(FALSE), not null
#  reject_straight_follow         :boolean          default(FALSE), not null
#  reject_new_follow              :boolean          default(FALSE), not null
#  hidden                         :boolean          default(FALSE), not null
#  detect_invalid_subscription    :boolean          default(FALSE), not null
#  reject_reply_exclude_followers :boolean          default(FALSE), not null
#  reject_friend                  :boolean          default(FALSE), not null
#

class DomainBlock < ApplicationRecord
  include Paginable
  include DomainNormalizable
  include DomainMaterializable

  enum severity: { silence: 0, suspend: 1, noop: 2 }

  validates :domain, presence: true, uniqueness: true, domain: true

  has_many :accounts, foreign_key: :domain, primary_key: :domain, inverse_of: false, dependent: nil
  delegate :count, to: :accounts, prefix: true

  scope :matches_domain, ->(value) { where(arel_table[:domain].matches("%#{value}%")) }
  scope :with_user_facing_limitations, -> { where(hidden: false) }
  scope :with_limitations, lambda {
    where(severity: [:silence, :suspend])
      .or(where(reject_media: true))
      .or(where(reject_favourite: true))
      .or(where(reject_reply: true))
      .or(where(reject_reply_exclude_followers: true))
      .or(where(reject_new_follow: true))
      .or(where(reject_straight_follow: true))
      .or(where(reject_friend: true))
  }
  scope :by_severity, -> { in_order_of(:severity, %w(noop silence suspend)).order(:domain) }

  def to_log_human_identifier
    domain
  end

  def policies
    if suspend?
      [:suspend]
    else
      [severity.to_sym,
       reject_media? ? :reject_media : nil,
       reject_favourite? ? :reject_favourite : nil,
       reject_reply? ? :reject_reply : nil,
       reject_reply_exclude_followers? ? :reject_reply_exclude_followers : nil,
       reject_send_sensitive? ? :reject_send_sensitive : nil,
       reject_hashtag? ? :reject_hashtag : nil,
       reject_straight_follow? ? :reject_straight_follow : nil,
       reject_new_follow? ? :reject_new_follow : nil,
       reject_friend? ? :reject_friend : nil,
       detect_invalid_subscription? ? :detect_invalid_subscription : nil,
       reject_reports? ? :reject_reports : nil].reject { |policy| policy == :noop || policy.nil? }
    end
  end

  class << self
    def suspend?(domain)
      !!rule_for(domain)&.suspend?
    end

    def silence?(domain)
      !!rule_for(domain)&.silence?
    end

    def reject_media?(domain)
      !!rule_for(domain)&.reject_media?
    end

    def reject_favourite?(domain)
      !!rule_for(domain)&.reject_favourite?
    end

    def reject_reply?(domain)
      !!rule_for(domain)&.reject_reply?
    end

    def reject_reply_exclude_followers?(domain)
      !!rule_for(domain)&.reject_reply_exclude_followers?
    end

    def reject_hashtag?(domain)
      !!rule_for(domain)&.reject_hashtag?
    end

    def reject_straight_follow?(domain)
      !!rule_for(domain)&.reject_straight_follow?
    end

    def reject_new_follow?(domain)
      !!rule_for(domain)&.reject_new_follow?
    end

    def reject_friend?(domain)
      !!rule_for(domain)&.reject_friend?
    end

    def detect_invalid_subscription?(domain)
      !!rule_for(domain)&.detect_invalid_subscription?
    end

    def reject_reports?(domain)
      !!rule_for(domain)&.reject_reports?
    end

    alias blocked? suspend?

    def rule_for(domain)
      return if domain.blank?

      uri      = Addressable::URI.new.tap { |u| u.host = domain.strip.delete('/') }
      segments = uri.normalized_host.split('.')
      variants = segments.map.with_index { |_, i| segments[i..].join('.') }

      where(domain: variants).order(Arel.sql('char_length(domain) desc')).first
    rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
      nil
    end
  end

  def stricter_than?(other_block)
    return true  if suspend?
    return false if other_block.suspend? && (silence? || noop?)
    return false if other_block.silence? && noop?

    (reject_media || !other_block.reject_media) && (reject_favourite || !other_block.reject_favourite) && (reject_reply || !other_block.reject_reply) && (reject_reply_exclude_followers || !other_block.reject_reply_exclude_followers) && (reject_reports || !other_block.reject_reports)
  end

  def public_domain
    return domain unless obfuscate?

    length        = domain.size
    visible_ratio = length / 4

    domain.chars.map.with_index do |chr, i|
      if i > visible_ratio && i < length - visible_ratio && chr != '.'
        '*'
      else
        chr
      end
    end.join
  end

  def domain_digest
    Digest::SHA256.hexdigest(domain)
  end
end
