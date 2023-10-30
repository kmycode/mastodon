# frozen_string_literal: true

class Vacuum::ListStatusesVacuum
  include Redisable

  LIST_STATUS_LIFE_DURATION = 1.day.freeze

  def perform
    vacuum_list_statuses!
  end

  private

  def vacuum_list_statuses!
    ListStatus.where('created_at < ?', LIST_STATUS_LIFE_DURATION.ago).in_batches.destroy_all
  end
end
