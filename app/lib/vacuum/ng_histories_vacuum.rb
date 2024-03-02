# frozen_string_literal: true

class Vacuum::NgHistoriesVacuum
  include Redisable

  HISTORY_LIFE_DURATION = 7.days.freeze

  def perform
    vacuum_histories!
  end

  private

  def vacuum_histories!
    NgwordHistory.where('created_at < ?', HISTORY_LIFE_DURATION.ago).in_batches.destroy_all
    NgRuleHistory.where('created_at < ?', HISTORY_LIFE_DURATION.ago).in_batches.destroy_all
  end
end
