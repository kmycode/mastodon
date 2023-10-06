# frozen_string_literal: true

# == Schema Information
#
# Table name: friend_domains
#
#  id                         :bigint(8)        not null, primary key
#  domain                     :string           default(""), not null
#  inbox_url                  :string           default(""), not null
#  active_state               :integer          default("idle"), not null
#  passive_state              :integer          default("idle"), not null
#  active_follow_activity_id  :string
#  passive_follow_activity_id :string
#  available                  :boolean          default(TRUE), not null
#  public_unlisted            :boolean          default(TRUE), not null
#  pseudo_relay               :boolean          default(FALSE), not null
#  unlocked                   :boolean          default(FALSE), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#

class FriendDomain < ApplicationRecord
  validates :domain, presence: true, uniqueness: true, if: :will_save_change_to_domain?
  validates :inbox_url, presence: true, uniqueness: true, if: :will_save_change_to_inbox_url?

  enum active_state: { idle: 0, pending: 1, accepted: 2, rejected: 3 }, _prefix: :i_am
  enum passive_state: { idle: 0, pending: 1, accepted: 2, rejected: 3 }, _prefix: :they_are

  scope :by_domain_and_subdomains, ->(domain) { where(domain: Instance.by_domain_and_subdomains(domain).select(:domain)) }

  before_destroy :ensure_disabled
  after_commit :set_default_inbox_url

  def mutual?
    i_am_accepted? && they_are_accepted?
  end

  def enable!
    activity_id = ActivityPub::TagManager.instance.generate_uri_for(nil)
    payload     = Oj.dump(follow_activity(activity_id))

    update!(active_state: :pending, active_follow_activity_id: activity_id)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  def disable!
    activity_id = ActivityPub::TagManager.instance.generate_uri_for(nil)
    payload     = Oj.dump(unfollow_activity(activity_id))

    update!(active_state: :idle, active_follow_activity_id: nil)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  def accept!
    activity_id = passive_follow_activity_id
    payload     = Oj.dump(accept_follow_activity(activity_id))

    update!(passive_state: :accepted)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  def reject!
    activity_id = passive_follow_activity_id
    payload     = Oj.dump(reject_follow_activity(activity_id))

    update!(passive_state: :rejected, passive_follow_activity_id: nil)
    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

  private

  def default_inbox_url
    Account.where(domain: domain).first&.inbox_url || "https://#{domain}/inbox"
  end

  def delete_for_friend!
    activity_id = ActivityPub::TagManager.instance.generate_uri_for(nil)
    payload     = Oj.dump(delete_follow_activity(activity_id))

    DeliveryFailureTracker.reset!(inbox_url)
    ActivityPub::DeliveryWorker.perform_async(payload, some_local_account.id, inbox_url)
  end

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
        id: active_follow_activity_id,
        type: 'Follow',
        actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
        object: ActivityPub::TagManager::COLLECTIONS[:public],
      },
    }
  end

  def accept_follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: "#{activity_id}#accepts/friends",
      type: 'Accept',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: activity_id,
    }
  end

  def reject_follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: "#{activity_id}#rejects/friends",
      type: 'Reject',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: ActivityPub::TagManager::COLLECTIONS[:public],
    }
  end

  def delete_follow_activity(activity_id)
    {
      '@context': ActivityPub::TagManager::CONTEXT,
      id: "#{activity_id}#delete/friends",
      type: 'Delete',
      actor: ActivityPub::TagManager.instance.uri_for(some_local_account),
      object: activity_id,
    }
  end

  def some_local_account
    @some_local_account ||= Account.representative
  end

  def ensure_disabled
    delete_for_friend!
  end

  def set_default_inbox_url
    self.inbox_url = default_inbox_url if inbox_url.blank?
  end
end
