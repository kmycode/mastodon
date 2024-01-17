# frozen_string_literal: true

# == Schema Information
#
# Table name: status_stats
#
#  id                            :bigint(8)        not null, primary key
#  status_id                     :bigint(8)        not null
#  replies_count                 :bigint(8)        default(0), not null
#  reblogs_count                 :bigint(8)        default(0), not null
#  favourites_count              :bigint(8)        default(0), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  emoji_reactions               :string
#  emoji_reactions_count         :integer          default(0), not null
#  emoji_reaction_accounts_count :integer          default(0), not null
#  status_referred_by_count      :integer          default(0), not null
#

class StatusStat < ApplicationRecord
  belongs_to :status, inverse_of: :status_stat

  def replies_count
    [attributes['replies_count'], 0].max
  end

  def reblogs_count
    [attributes['reblogs_count'], 0].max
  end

  def favourites_count
    [attributes['favourites_count'], 0].max
  end

  def emoji_reactions
    attributes['emoji_reactions'] || ''
  end

  def emoji_reactions_count
    [attributes['emoji_reactions_count'], 0].max
  end

  def emoji_reaction_accounts_count
    [attributes['emoji_reaction_accounts_count'], 0].max
  end

  def status_referred_by_count
    [attributes['status_referred_by_count'] || 0, 0].max
  end
end
