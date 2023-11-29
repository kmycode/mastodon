# frozen_string_literal: true

# == Schema Information
#
# Table name: statuses
#
#  id                           :bigint(8)        not null, primary key
#  uri                          :string
#  text                         :text             default(""), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  in_reply_to_id               :bigint(8)
#  reblog_of_id                 :bigint(8)
#  url                          :string
#  sensitive                    :boolean          default(FALSE), not null
#  visibility                   :integer          default("public"), not null
#  spoiler_text                 :text             default(""), not null
#  reply                        :boolean          default(FALSE), not null
#  language                     :string
#  conversation_id              :bigint(8)
#  local                        :boolean
#  account_id                   :bigint(8)        not null
#  application_id               :bigint(8)
#  in_reply_to_account_id       :bigint(8)
#  poll_id                      :bigint(8)
#  deleted_at                   :datetime
#  edited_at                    :datetime
#  trendable                    :boolean
#  ordered_media_attachment_ids :bigint(8)        is an Array
#  searchability                :integer
#  markdown                     :boolean          default(FALSE)
#  limited_scope                :integer
#  quote_of_id                  :bigint(8)
#

require 'ostruct'

class Status < ApplicationRecord
  include Discard::Model
  include Paginable
  include Cacheable
  include StatusThreadingConcern
  include StatusSnapshotConcern
  include RateLimitable
  include StatusSafeReblogInsert
  include StatusSearchConcern
  include DtlHelper

  rate_limit by: :account, family: :statuses

  self.discard_column = :deleted_at

  # If `override_timestamps` is set at creation time, Snowflake ID creation
  # will be based on current time instead of `created_at`
  attr_accessor :override_timestamps

  update_index('statuses', :proper)
  update_index('public_statuses', :proper)

  enum visibility: { public: 0, unlisted: 1, private: 2, direct: 3, limited: 4, public_unlisted: 10, login: 11 }, _suffix: :visibility
  enum searchability: { public: 0, private: 1, direct: 2, limited: 3, unsupported: 4, public_unlisted: 10 }, _suffix: :searchability
  enum limited_scope: { none: 0, mutual: 1, circle: 2, personal: 3, reply: 4 }, _suffix: :limited

  belongs_to :application, class_name: 'Doorkeeper::Application', optional: true

  belongs_to :account, inverse_of: :statuses
  belongs_to :in_reply_to_account, class_name: 'Account', optional: true
  belongs_to :conversation, optional: true
  has_one :owned_conversation, class_name: 'Conversation', foreign_key: 'ancestor_status_id', dependent: :nullify, inverse_of: false
  belongs_to :preloadable_poll, class_name: 'Poll', foreign_key: 'poll_id', optional: true, inverse_of: false

  belongs_to :thread, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :replies, optional: true
  belongs_to :reblog, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblogs, optional: true
  belongs_to :quote, foreign_key: 'quote_of_id', class_name: 'Status', inverse_of: :quotes, optional: true

  has_many :favourites, inverse_of: :status, dependent: :destroy
  has_many :emoji_reactions, inverse_of: :status, dependent: :destroy
  has_many :bookmarks, inverse_of: :status, dependent: :destroy
  has_many :reblogs, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblog, dependent: :destroy
  has_many :reblogged_by_accounts, through: :reblogs, class_name: 'Account', source: :account
  has_many :quotes, foreign_key: 'quote_of_id', class_name: 'Status', inverse_of: :quote
  has_many :quoted_by_accounts, through: :quotes, class_name: 'Account', source: :account
  has_many :replies, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :thread
  has_many :mentions, dependent: :destroy, inverse_of: :status
  has_many :mentioned_accounts, through: :mentions, source: :account, class_name: 'Account'
  has_many :active_mentions, -> { active }, class_name: 'Mention', inverse_of: :status
  has_many :silent_mentions, -> { silent }, class_name: 'Mention', inverse_of: :status
  has_many :media_attachments, dependent: :nullify
  has_many :reference_objects, class_name: 'StatusReference', inverse_of: :status, dependent: :destroy
  has_many :references, through: :reference_objects, class_name: 'Status', source: :target_status
  has_many :referenced_by_status_objects, foreign_key: 'target_status_id', class_name: 'StatusReference', inverse_of: :target_status, dependent: :destroy
  has_many :referenced_by_statuses, through: :referenced_by_status_objects, class_name: 'Status', source: :status
  has_many :capability_tokens, class_name: 'StatusCapabilityToken', inverse_of: :status, dependent: :destroy
  has_many :bookmark_category_relationships, class_name: 'BookmarkCategoryStatus', inverse_of: :status, dependent: :destroy
  has_many :bookmark_categories, class_name: 'BookmarkCategory', through: :bookmark_category_relationships, source: :bookmark_category
  has_many :joined_bookmark_categories, class_name: 'BookmarkCategory', through: :bookmark_category_relationships, source: :bookmark_category

  # Those associations are used for the private search index
  has_many :local_mentioned, -> { merge(Account.local) }, through: :active_mentions, source: :account
  has_many :local_favorited, -> { merge(Account.local) }, through: :favourites, source: :account
  has_many :local_reblogged, -> { merge(Account.local) }, through: :reblogs, source: :account
  has_many :local_bookmarked, -> { merge(Account.local) }, through: :bookmarks, source: :account
  has_many :local_bookmark_categoried, -> { merge(Account.local) }, through: :bookmark_categories, source: :account
  has_many :local_emoji_reacted, -> { merge(Account.local) }, through: :emoji_reactions, source: :account
  has_many :local_referenced, -> { merge(Account.local) }, through: :referenced_by_statuses, source: :account

  has_and_belongs_to_many :tags

  has_one :preview_cards_status, inverse_of: :status # Because of a composite primary key, the dependent option cannot be used
  has_one :notification, as: :activity, dependent: :destroy
  has_one :status_stat, inverse_of: :status
  has_one :poll, inverse_of: :status, dependent: :destroy
  has_one :trend, class_name: 'StatusTrend', inverse_of: :status
  has_one :scheduled_expiration_status, inverse_of: :status, dependent: :destroy
  has_one :circle_status, inverse_of: :status, dependent: :destroy
  has_many :list_status, inverse_of: :status, dependent: :destroy

  validates :uri, uniqueness: true, presence: true, unless: :local?
  validates :text, presence: true, unless: -> { with_media? || reblog? }
  validates_with StatusLengthValidator
  validates_with DisallowedHashtagsValidator
  validates :reblog, uniqueness: { scope: :account }, if: :reblog?
  validates :visibility, exclusion: { in: %w(direct limited) }, if: :reblog?

  accepts_nested_attributes_for :poll

  default_scope { recent.kept }

  scope :recent, -> { reorder(id: :desc) }
  scope :remote, -> { where(local: false).where.not(uri: nil) }
  scope :local,  -> { where(local: true).or(where(uri: nil)) }
  scope :with_accounts, ->(ids) { where(id: ids).includes(:account) }
  scope :without_replies, -> { where('statuses.reply = FALSE OR statuses.in_reply_to_account_id = statuses.account_id') }
  scope :without_reblogs, -> { where(statuses: { reblog_of_id: nil }) }
  scope :with_public_visibility, -> { where(visibility: [:public, :public_unlisted, :login]) }
  scope :with_public_search_visibility, -> { merge(where(visibility: [:public, :public_unlisted, :login]).or(Status.where(searchability: [:public, :public_unlisted]))) }
  scope :tagged_with, ->(tag_ids) { joins(:statuses_tags).where(statuses_tags: { tag_id: tag_ids }) }
  scope :excluding_silenced_accounts, -> { left_outer_joins(:account).where(accounts: { silenced_at: nil }) }
  scope :including_silenced_accounts, -> { left_outer_joins(:account).where.not(accounts: { silenced_at: nil }) }
  scope :not_excluded_by_account, ->(account) { where.not(account_id: account.excluded_from_timeline_account_ids) }
  scope :not_domain_blocked_by_account, ->(account) { account.excluded_from_timeline_domains.blank? ? left_outer_joins(:account) : left_outer_joins(:account).where('accounts.domain IS NULL OR accounts.domain NOT IN (?)', account.excluded_from_timeline_domains) }
  scope :tagged_with_all, lambda { |tag_ids|
    Array(tag_ids).map(&:to_i).reduce(self) do |result, id|
      result.where(<<~SQL.squish, tag_id: id)
        EXISTS(SELECT 1 FROM statuses_tags WHERE statuses_tags.status_id = statuses.id AND statuses_tags.tag_id = :tag_id)
      SQL
    end
  }
  scope :tagged_with_none, lambda { |tag_ids|
    where('NOT EXISTS (SELECT * FROM statuses_tags forbidden WHERE forbidden.status_id = statuses.id AND forbidden.tag_id IN (?))', tag_ids)
  }
  scope :unset_searchability, -> { where(searchability: nil, reblog_of_id: nil) }

  after_create_commit :trigger_create_webhooks
  after_update_commit :trigger_update_webhooks

  after_create_commit  :increment_counter_caches
  after_destroy_commit :decrement_counter_caches

  after_create_commit :store_uri, if: :local?
  after_create_commit :update_statistics, if: :local?

  before_validation :prepare_contents, if: :local?
  before_validation :set_reblog
  before_validation :set_visibility
  before_validation :set_searchability
  before_validation :set_conversation
  before_validation :set_local

  around_create Mastodon::Snowflake::Callbacks

  after_create :set_poll_id

  # The `prepend: true` option below ensures this runs before
  # the `dependent: destroy` callbacks remove relevant records
  before_destroy :unlink_from_conversations!, prepend: true
  before_destroy :reset_preview_card!

  cache_associated :application,
                   :media_attachments,
                   :conversation,
                   :status_stat,
                   :tags,
                   :preloadable_poll,
                   :reference_objects,
                   :scheduled_expiration_status,
                   preview_cards_status: [:preview_card],
                   account: [:account_stat, user: :role],
                   active_mentions: { account: :account_stat },
                   reblog: [
                     :application,
                     :tags,
                     :media_attachments,
                     :conversation,
                     :status_stat,
                     :preloadable_poll,
                     :reference_objects,
                     :scheduled_expiration_status,
                     preview_cards_status: [:preview_card],
                     account: [:account_stat, user: :role],
                     active_mentions: { account: :account_stat },
                   ],
                   quote: [
                     :application,
                     :tags,
                     :media_attachments,
                     :conversation,
                     :status_stat,
                     :preloadable_poll,
                     :reference_objects,
                     :scheduled_expiration_status,
                     preview_cards_status: [:preview_card],
                     account: [:account_stat, user: :role],
                     active_mentions: { account: :account_stat },
                   ],
                   thread: { account: :account_stat }

  delegate :domain, to: :account, prefix: true

  REAL_TIME_WINDOW = 6.hours

  def cache_key
    "v3:#{super}"
  end

  def to_log_human_identifier
    account.acct
  end

  def to_log_permalink
    ActivityPub::TagManager.instance.uri_for(self)
  end

  def reply?
    !in_reply_to_id.nil? || attributes['reply']
  end

  def local?
    attributes['local'] || uri.nil?
  end

  def in_reply_to_local_account?
    reply? && thread&.account&.local?
  end

  def reblog?
    !reblog_of_id.nil?
  end

  def quote?
    !quote_of_id.nil? && !quote.nil?
  end

  def within_realtime_window?
    created_at >= REAL_TIME_WINDOW.ago
  end

  def verb
    if destroyed?
      :delete
    else
      reblog? ? :share : :post
    end
  end

  def object_type
    reply? ? :comment : :note
  end

  def proper
    reblog? ? reblog : self
  end

  def content
    proper.text
  end

  def target
    reblog
  end

  def preview_card
    preview_cards_status&.preview_card&.tap { |x| x.original_url = preview_cards_status.url }
  end

  def reset_preview_card!
    PreviewCardsStatus.where(status_id: id).delete_all
  end

  def hidden?
    !distributable?
  end

  def distributable?
    public_visibility? || unlisted_visibility? || public_unlisted_visibility?
  end

  alias sign? distributable?

  def with_media?
    ordered_media_attachments.any?
  end

  def expired?
    false
    # !expired_at.nil?
  end

  def with_preview_card?
    preview_cards_status.present?
  end

  def with_poll?
    preloadable_poll.present?
  end

  def with_status_reference?
    reference_objects.any?
  end

  def non_sensitive_with_media?
    !sensitive? && with_media?
  end

  def reported?
    @reported ||= Report.where(target_account: account).unresolved.where('? = ANY(status_ids)', id).exists?
  end

  def dtl?
    (%w(public public_unlisted login).include?(visibility) || (unlisted_visibility? && public_searchability?)) && tags.where(name: dtl_tag_name).exists?
  end

  def emojis
    return @emojis if defined?(@emojis)

    fields  = [spoiler_text, text]
    fields += preloadable_poll.options unless preloadable_poll.nil?

    @emojis = CustomEmoji.from_text(fields.join(' '), account.domain)
  end

  def ordered_media_attachments
    if ordered_media_attachment_ids.nil?
      media_attachments
    else
      map = media_attachments.index_by(&:id)
      ordered_media_attachment_ids.filter_map { |media_attachment_id| map[media_attachment_id] }
    end
  end

  def replies_count
    status_stat&.replies_count || 0
  end

  def reblogs_count
    status_stat&.reblogs_count || 0
  end

  def favourites_count
    status_stat&.favourites_count || 0
  end

  def emoji_reactions_count
    status_stat&.emoji_reactions_count || 0
  end

  def emoji_reaction_accounts_count
    status_stat&.emoji_reaction_accounts_count || 0
  end

  def status_referred_by_count
    status_stat&.status_referred_by_count || 0
  end

  def increment_count!(key)
    update_status_stat!(key => public_send(key) + 1)
  end

  def decrement_count!(key)
    update_status_stat!(key => [public_send(key) - 1, 0].max)
  end

  def add_status_referred_by_count!(diff)
    update_status_stat!(status_referred_by_count: [public_send(:status_referred_by_count) + diff, 0].max)
  end

  def emoji_reactions_grouped_by_name(account = nil, **options)
    return [] if account.present? && !self.account.show_emoji_reaction?(account)
    return [] if account.nil? && !options[:force] && self.account.emoji_reaction_policy != :allow

    permitted_account_ids = options[:permitted_account_ids]

    (Oj.load(status_stat&.emoji_reactions || '', mode: :strict) || []).tap do |emoji_reactions|
      if account.present?
        public_emoji_reactions = []

        emoji_reactions.each do |emoji_reaction|
          emoji_reaction['me'] = emoji_reaction['account_ids'].include?(account.id.to_s)
          emoji_reaction['account_ids'] -= account.excluded_from_timeline_account_ids.map(&:to_s)

          accounts = []
          if permitted_account_ids
            emoji_reaction['account_ids'] = emoji_reaction['account_ids'] & permitted_account_ids.map(&:to_s)
          else
            accounts = Account.where(id: emoji_reaction['account_ids'], silenced_at: nil, suspended_at: nil)
            accounts = accounts.where('domain IS NULL OR domain NOT IN (?)', account.excluded_from_timeline_domains) if account.excluded_from_timeline_domains.size.positive?
            emoji_reaction['account_ids'] = accounts.pluck(:id).map(&:to_s)
          end

          emoji_reaction['count'] = emoji_reaction['account_ids'].size
          public_emoji_reactions << emoji_reaction if (emoji_reaction['count']).positive?
        end

        public_emoji_reactions
      else
        emoji_reactions
      end
    end
  end

  def generate_emoji_reactions_grouped_by_name
    records = emoji_reactions.group(:name).order(Arel.sql('MIN(created_at) ASC')).select('name, min(custom_emoji_id) as custom_emoji_id, count(*) as count, array_agg(account_id::text order by created_at) as account_ids')
    Oj.dump(ActiveModelSerializers::SerializableResource.new(records, each_serializer: REST::EmojiReactionsGroupedByNameSerializer, scope: nil, scope_name: :current_user))
  end

  def refresh_emoji_reactions_grouped_by_name!
    generate_emoji_reactions_grouped_by_name.tap do |emoji_reactions_json|
      update_status_stat!(emoji_reactions: emoji_reactions_json, emoji_reactions_count: emoji_reactions.size, emoji_reaction_accounts_count: emoji_reactions.map(&:account_id).uniq.size)
    end
  end

  def generate_emoji_reactions_grouped_by_account
    # TODO: for serializer
    EmojiReaction.where(status_id: id).group_by(&:account)
  end

  def trendable?
    if attributes['trendable'].nil?
      account.trendable?
    else
      attributes['trendable']
    end
  end

  def requires_review?
    attributes['trendable'].nil? && account.requires_review?
  end

  def requires_review_notification?
    attributes['trendable'].nil? && account.requires_review_notification?
  end

  def compute_searchability
    local = account.local?
    check_searchability = public_unlisted_searchability? ? 'public' : searchability

    return 'private' if %w(public public_unlisted).include?(check_searchability) && account.silenced?
    return 'direct' if unsupported_searchability?
    return check_searchability if local && !check_searchability.nil?
    return 'direct' if local || %i(public private direct limited).exclude?(account.searchability.to_sym)

    account_searchability = Status.searchabilities[account.searchability]
    status_searchability = Status.searchabilities[check_searchability.nil? ? 'direct' : check_searchability]
    Status.searchabilities.invert.fetch([account_searchability, status_searchability].max) || 'direct'
  end

  def compute_searchability_activitypub
    return 'private' if public_unlisted_searchability?

    compute_searchability
  end

  def compute_searchability_local
    return 'public_unlisted' if public_unlisted_searchability?

    compute_searchability
  end

  def searchable_visibility
    return limited_scope if limited_visibility? && !none_limited?

    visibility
  end

  class << self
    def selectable_visibilities
      vs = visibilities.keys - %w(direct limited)
      vs -= %w(public_unlisted) unless Setting.enable_public_unlisted_visibility
      vs
    end

    def selectable_reblog_visibilities
      %w(unset) + selectable_visibilities
    end

    def selectable_searchabilities
      searchabilities.keys - %w(unsupported)
    end

    def selectable_searchabilities_for_search
      searchabilities.keys - %w(public_unlisted unsupported)
    end

    def favourites_map(status_ids, account_id)
      Favourite.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |f, h| h[f.status_id] = true }
    end

    def bookmarks_map(status_ids, account_id)
      Bookmark.select('status_id').where(status_id: status_ids).where(account_id: account_id).map { |f| [f.status_id, true] }.to_h
    end

    def reblogs_map(status_ids, account_id)
      unscoped.select('reblog_of_id').where(reblog_of_id: status_ids).where(account_id: account_id).each_with_object({}) { |s, h| h[s.reblog_of_id] = true }
    end

    def mutes_map(conversation_ids, account_id)
      ConversationMute.select('conversation_id').where(conversation_id: conversation_ids).where(account_id: account_id).each_with_object({}) { |m, h| h[m.conversation_id] = true }
    end

    def blocks_map(account_ids, account_id)
      Block.where(account_id: account_id, target_account_id: account_ids).each_with_object({}) { |b, h| h[b.target_account_id] = true }
    end

    def domain_blocks_map(domains, account_id)
      AccountDomainBlock.where(account_id: account_id, domain: domains).each_with_object({}) { |d, h| h[d.domain] = true }
    end

    def pins_map(status_ids, account_id)
      StatusPin.select('status_id').where(status_id: status_ids).where(account_id: account_id).each_with_object({}) { |p, h| h[p.status_id] = true }
    end

    def emoji_reaction_allows_map(status_ids, account_id)
      my_account = Account.find_by(id: account_id)
      Status.where(id: status_ids).pluck(:account_id).uniq.index_with { |a| Account.find_by(id: a).show_emoji_reaction?(my_account) }
    end

    def emoji_reaction_availables_map(domains)
      domains.index_with { |d| InstanceInfo.emoji_reaction_available?(d) }
    end

    def reload_stale_associations!(cached_items)
      account_ids = []

      cached_items.each do |item|
        account_ids << item.account_id
        account_ids << item.reblog.account_id if item.reblog?
      end

      account_ids.uniq!

      status_ids = cached_items.map { |item| item.reblog? ? item.reblog_of_id : item.id }.uniq

      return if account_ids.empty?

      accounts = Account.where(id: account_ids).includes(:account_stat, :user).index_by(&:id)

      status_stats = StatusStat.where(status_id: status_ids).index_by(&:status_id)

      cached_items.each do |item|
        item.account = accounts[item.account_id]
        item.reblog.account = accounts[item.reblog.account_id] if item.reblog?

        if item.reblog?
          status_stat = status_stats[item.reblog.id]
          item.reblog.status_stat = status_stat if status_stat.present?
        else
          status_stat = status_stats[item.id]
          item.status_stat = status_stat if status_stat.present?
        end
      end
    end

    def from_text(text)
      return [] if text.blank?

      text.scan(FetchLinkCardService::URL_PATTERN).map(&:second).uniq.filter_map do |url|
        status = if TagManager.instance.local_url?(url)
                   ActivityPub::TagManager.instance.uri_to_resource(url, Status)
                 else
                   EntityCache.instance.status(url)
                 end

        status&.distributable? ? status : nil
      end
    end
  end

  def status_stat
    super || build_status_stat
  end

  def discard_with_reblogs
    discard_time = Time.current
    Status.unscoped.where(reblog_of_id: id, deleted_at: [nil, deleted_at]).in_batches.update_all(deleted_at: discard_time) unless reblog?
    update_attribute(:deleted_at, discard_time)
  end

  def unlink_from_conversations!
    return unless direct_visibility?

    inbox_owners = mentioned_accounts.local
    inbox_owners += [account] if account.local?

    inbox_owners.each do |inbox_owner|
      AccountConversation.remove_status(inbox_owner, self)
    end
  end

  def distributable_friend?
    public_visibility? || public_unlisted_visibility? || (unlisted_visibility? && (public_searchability? || public_unlisted_searchability?))
  end

  private

  def update_status_stat!(attrs)
    return if marked_for_destruction? || destroyed?

    status_stat.update(attrs)
  end

  def store_uri
    update_column(:uri, ActivityPub::TagManager.instance.uri_for(self)) if uri.nil?
  end

  def prepare_contents
    text&.strip!
    spoiler_text&.strip!
  end

  def set_reblog
    self.reblog = reblog.reblog if reblog? && reblog.reblog?
  end

  def set_poll_id
    update_column(:poll_id, poll.id) if association(:poll).loaded? && poll.present?
  end

  def set_visibility
    self.visibility = reblog.visibility if reblog? && visibility.nil?
    self.visibility = (account.locked? ? :private : :public) if visibility.nil?
    self.sensitive  = false if sensitive.nil?
  end

  def set_searchability
    return if searchability.nil?

    self.searchability = if %w(public public_unlisted login unlisted).include?(visibility)
                           searchability
                         elsif visibility == 'limited' || visibility == 'direct'
                           searchability == 'limited' ? :limited : :direct
                         elsif visibility == 'private'
                           searchability == 'public' || searchability == 'public_unlisted' ? :private : searchability
                         else
                           :direct
                         end
  end

  def set_conversation
    self.thread = thread.reblog if thread&.reblog?

    self.reply = !(in_reply_to_id.nil? && thread.nil?) unless reply

    if reply? && !thread.nil? && (!limited_visibility? || none_limited? || reply_limited?)
      self.in_reply_to_account_id = carried_over_reply_to_account_id
      self.conversation_id        = thread.conversation_id if conversation_id.nil?
    elsif conversation_id.nil?
      if local?
        self.owned_conversation = Conversation.new
        self.conversation = owned_conversation
      else
        self.conversation = Conversation.new
      end
    end
  end

  def carried_over_reply_to_account_id
    if thread.account_id == account_id && thread.reply?
      thread.in_reply_to_account_id
    else
      thread.account_id
    end
  end

  def set_local
    self.local = account.local?
  end

  def update_statistics
    return unless distributable?

    ActivityTracker.increment('activity:statuses:local')
  end

  def increment_counter_caches
    return if direct_visibility?

    account&.increment_count!(:statuses_count)
    reblog&.increment_count!(:reblogs_count) if reblog?
    thread&.increment_count!(:replies_count) if in_reply_to_id.present? && distributable?
  end

  def decrement_counter_caches
    return if direct_visibility? || new_record?

    account&.decrement_count!(:statuses_count)
    reblog&.decrement_count!(:reblogs_count) if reblog?
    thread&.decrement_count!(:replies_count) if in_reply_to_id.present? && distributable?
  end

  def trigger_create_webhooks
    TriggerWebhookWorker.perform_async('status.created', 'Status', id) if local?
  end

  def trigger_update_webhooks
    TriggerWebhookWorker.perform_async('status.updated', 'Status', id) if local?
  end
end
