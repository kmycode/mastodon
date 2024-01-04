# frozen_string_literal: true

# == Schema Information
#
# Table name: antennas
#
#  id               :bigint(8)        not null, primary key
#  account_id       :bigint(8)        not null
#  list_id          :bigint(8)        not null
#  title            :string           default(""), not null
#  keywords         :jsonb
#  exclude_keywords :jsonb
#  any_domains      :boolean          default(TRUE), not null
#  any_tags         :boolean          default(TRUE), not null
#  any_accounts     :boolean          default(TRUE), not null
#  any_keywords     :boolean          default(TRUE), not null
#  available        :boolean          default(TRUE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  expires_at       :datetime
#  with_media_only  :boolean          default(FALSE), not null
#  exclude_domains  :jsonb
#  exclude_accounts :jsonb
#  exclude_tags     :jsonb
#  stl              :boolean          default(FALSE), not null
#  ignore_reblog    :boolean          default(FALSE), not null
#  insert_feeds     :boolean          default(FALSE), not null
#  ltl              :boolean          default(FALSE), not null
#
class Antenna < ApplicationRecord
  include Expireable

  LIMIT = 30
  DOMAINS_PER_ANTENNA_LIMIT = 20
  ACCOUNTS_PER_ANTENNA_LIMIT = 100
  TAGS_PER_ANTENNA_LIMIT = 50
  KEYWORDS_PER_ANTENNA_LIMIT = 100

  has_many :antenna_domains, inverse_of: :antenna, dependent: :destroy
  has_many :antenna_tags, inverse_of: :antenna, dependent: :destroy
  has_many :tags, through: :antenna_tags
  has_many :antenna_accounts, inverse_of: :antenna, dependent: :destroy
  has_many :accounts, through: :antenna_accounts

  belongs_to :account
  belongs_to :list, optional: true

  scope :stls, -> { where(stl: true) }
  scope :ltls, -> { where(ltl: true) }
  scope :all_keywords, -> { where(any_keywords: true) }
  scope :all_domains, -> { where(any_domains: true) }
  scope :all_accounts, -> { where(any_accounts: true) }
  scope :all_tags, -> { where(any_tags: true) }
  scope :availables, -> { where(available: true).where(Arel.sql('any_keywords = FALSE OR any_domains = FALSE OR any_accounts = FALSE OR any_tags = FALSE')) }
  scope :available_stls, -> { where(available: true, stl: true) }
  scope :available_ltls, -> { where(available: true, stl: false, ltl: true) }

  validates :title, presence: true

  validate :list_owner
  validate :validate_limit
  validate :validate_stl_limit
  validate :validate_ltl_limit

  before_destroy :clean_feed_manager

  def list_owner
    raise Mastodon::ValidationError, I18n.t('antennas.errors.invalid_list_owner') if !list_id.zero? && list.present? && list.account != account
  end

  def enabled?
    enabled_config? && !expired?
  end

  def enabled_config?
    available && enabled_config_raws?
  end

  def enabled_config_raws?
    !(any_keywords && any_domains && any_accounts && any_tags)
  end

  def expires_in
    return @expires_in if defined?(@expires_in)
    return nil if expires_at.nil?

    [30.minutes, 1.hour, 6.hours, 12.hours, 1.day, 1.week].find { |expires_in| expires_in.from_now >= expires_at }
  end

  def context
    context = []
    context << 'domain' unless any_domains
    context << 'tag' unless any_tags
    context << 'keyword' unless any_keywords
    context << 'account' unless any_accounts
    context
  end

  private

  def validate_limit
    errors.add(:base, I18n.t('antennas.errors.over_limit', limit: LIMIT)) if account.antennas.count >= LIMIT
  end

  def validate_stl_limit
    return unless stl

    stls = account.antennas.where(stl: true).where.not(id: id)

    errors.add(:base, I18n.t('antennas.errors.over_stl_limit', limit: 1)) if if insert_feeds
                                                                               list_id.zero? ? stls.any? { |tl| tl.list_id.zero? } : stls.any? { |tl| tl.list_id != 0 }
                                                                             else
                                                                               stls.any? { |tl| !tl.insert_feeds }
                                                                             end
  end

  def validate_ltl_limit
    return unless ltl

    ltls = account.antennas.where(ltl: true).where.not(id: id)

    errors.add(:base, I18n.t('antennas.errors.over_ltl_limit', limit: 1)) if if insert_feeds
                                                                               list_id.zero? ? ltls.any? { |tl| tl.list_id.zero? } : ltls.any? { |tl| tl.list_id != 0 }
                                                                             else
                                                                               ltls.any? { |tl| !tl.insert_feeds }
                                                                             end
  end

  def clean_feed_manager
    FeedManager.instance.clean_feeds!(:antenna, [id])
  end
end
