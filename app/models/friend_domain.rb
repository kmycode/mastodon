# frozen_string_literal: true

# == Schema Information
#
# Table name: friend_domains
#
#  id                         :bigint(8)        not null, primary key
#  domain                     :string           default(""), not null
#  active_state               :integer          default("idle"), not null
#  passive_state              :integer          default("idle"), not null
#  active_follow_activity_id  :string
#  passive_follow_activity_id :string
#  local_visibility           :boolean          default(TRUE), not null
#  local_searchability        :boolean          default(TRUE), not null
#  pseudo_relay               :boolean          default(FALSE), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#

class FriendDomain < ApplicationRecord
  validates :domain, presence: true, uniqueness: true, if: :will_save_change_to_domain?

  enum active_state: { idle: 0, pending: 1, accepted: 2, rejected: 3 }, _prefix: :i_am
  enum passive_state: { idle: 0, pending: 1, accepted: 2, rejected: 3 }, _prefix: :they_are

  before_destroy :ensure_disabled

  def mutual?
    i_am_accepted? && they_are_accepted?
  end

  def enable!
    activity_id = ActivityPub::TagManager.instance.generate_uri_for(nil)
    payload     = Oj.dump(follow_activity(activity_id))

    update!(state: :pending, follow_activity_id: activity_id)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  def disable!
    activity_id = ActivityPub::TagManager.instance.generate_uri_for(nil)
    payload     = Oj.dump(unfollow_activity(activity_id))

    update!(state: :idle, follow_activity_id: nil)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  private

  def follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: activity_id,
      type: 'Follow',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: ActivityPub::TagManager::COLLECTIONS[:public],
    }
  end

  def unfollow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: activity_id,
      type: 'Undo',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: {
        id: follow_activity_id,
        type: 'Follow',
        actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
        object: ActivityPub::TagManager::COLLECTIONS[:public],
      },
    }
  end

  def accept_follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: activity_id,
      type: 'Accept',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: ActivityPub::TagManager::COLLECTIONS[:public],
    }
  end

  def reject_follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: activity_id,
      type: 'Reject',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: ActivityPub::TagManager::COLLECTIONS[:public],
    }
  end

  def some_local_account
    @some_local_account ||= Account.representative
  end

  def ensure_disabled
    disable! if enabled?
  end
end
