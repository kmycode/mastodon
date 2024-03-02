# frozen_string_literal: true

class Vacuum::StatusesVacuum
  include Redisable

  def initialize(retention_period)
    @retention_period = retention_period
  end

  def perform
    vacuum_statuses! if @retention_period.present?
  end

  private

  def vacuum_statuses!
    statuses_scope.in_batches do |statuses|
      # Side-effects not covered by foreign keys, such
      # as the search index, must be handled first.
      statuses.direct_visibility
              .includes(mentions: :account)
              .find_each(&:unlink_from_conversations!)
      if Chewy.enabled?
        remove_from_index(statuses.ids, 'chewy:queue:StatusesIndex')
        remove_from_index(statuses.ids, 'chewy:queue:PublicStatusesIndex')
      end

      # Foreign keys take care of most associated records for us.
      # Media attachments will be orphaned.
      statuses.delete_all
    end
  end

  def statuses_scope
    scope = Status.unscoped.kept
                  .joins(:account).merge(Account.remote)
                  .where('statuses.id < ?', retention_period_as_id)

    if Setting.delete_content_cache_without_reaction
      scope = scope.where.not(id: favourited_statuses)
                   .where.not(id: bookmarked_statuses)
    end

    scope
  end

  def favourited_statuses
    Favourite.local.select(:status_id)
  end

  def bookmarked_statuses
    Bookmark.select(:status_id)
  end

  def retention_period_as_id
    Mastodon::Snowflake.id_at(@retention_period.ago, with_random: false)
  end

  def remove_from_index(status_ids, index)
    with_redis { |redis| redis.sadd(index, status_ids) }
  end
end
