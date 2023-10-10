# frozen_string_literal: true

require 'rails_helper'

describe FriendDomain do
  let(:friend) { Fabricate(:friend_domain, domain: 'foo.bar', inbox_url: 'https://foo.bar/inbox') }

  before do
    stub_request(:post, 'https://foo.bar/inbox')
  end

  describe '#follow!' do
    it 'call inbox' do
      friend.update(active_state: :accepted, passive_state: :accepted)
      friend.follow!
      expect(friend.active_follow_activity_id).to_not be_nil
      expect(friend.i_am_pending?).to be true
      expect(friend.they_are_idle?).to be true
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        id: friend.active_follow_activity_id,
        type: 'Follow',
        actor: 'https://cb6e6126.ngrok.io/actor',
        object: 'https://www.w3.org/ns/activitystreams#Public',
      }))).to have_been_made.once
    end
  end

  describe '#unfollow!' do
    it 'call inbox' do
      friend.update(active_follow_activity_id: 'ohagi', active_state: :accepted, passive_state: :accepted)
      friend.unfollow!
      expect(friend.active_follow_activity_id).to be_nil
      expect(friend.i_am_idle?).to be true
      expect(friend.they_are_idle?).to be true
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Undo',
        object: {
          id: 'ohagi',
          type: 'Follow',
          actor: 'https://cb6e6126.ngrok.io/actor',
          object: 'https://www.w3.org/ns/activitystreams#Public',
        },
      }))).to have_been_made.once
    end
  end

  describe '#accept!' do
    it 'call inbox' do
      friend.update(passive_follow_activity_id: 'ohagi', active_state: :accepted, passive_state: :pending)
      friend.accept!
      expect(friend.they_are_accepted?).to be true
      expect(friend.i_am_idle?).to be true
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        id: 'ohagi#accepts/friends',
        type: 'Accept',
        actor: 'https://cb6e6126.ngrok.io/actor',
        object: 'ohagi',
      }))).to have_been_made.once
    end
  end

  describe '#reject!' do
    it 'call inbox' do
      friend.update(passive_follow_activity_id: 'ohagi', active_state: :accepted, passive_state: :pending)
      friend.reject!
      expect(friend.they_are_rejected?).to be true
      expect(friend.i_am_idle?).to be true
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        id: 'ohagi#rejects/friends',
        type: 'Reject',
        actor: 'https://cb6e6126.ngrok.io/actor',
        object: 'ohagi',
      }))).to have_been_made.once
    end
  end

  describe '#delete!' do
    it 'call inbox' do
      friend.update(active_state: :pending)
      friend.destroy
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Delete',
        actor: 'https://cb6e6126.ngrok.io/actor',
        object: 'https://www.w3.org/ns/activitystreams#Public',
      }))).to have_been_made.once
    end
  end
end
