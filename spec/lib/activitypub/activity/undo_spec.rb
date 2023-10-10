# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Undo do
  subject { described_class.new(json, sender) }

  let(:sender) { Fabricate(:account, domain: 'example.com') }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Undo',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: object_json,
    }.with_indifferent_access
  end

  describe '#perform' do
    context 'with Announce' do
      let(:status) { Fabricate(:status) }

      let(:object_json) do
        {
          id: 'bar',
          type: 'Announce',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: ActivityPub::TagManager.instance.uri_for(status),
          atomUri: 'barbar',
        }
      end

      context 'when not atomUri' do
        before do
          Fabricate(:status, reblog: status, account: sender, uri: 'bar')
        end

        it 'deletes the reblog' do
          subject.perform
          expect(sender.reblogged?(status)).to be false
        end
      end

      context 'with atomUri' do
        before do
          Fabricate(:status, reblog: status, account: sender, uri: 'barbar')
        end

        it 'deletes the reblog by atomUri' do
          subject.perform
          expect(sender.reblogged?(status)).to be false
        end
      end

      context 'with only object uri' do
        let(:object_json) { 'bar' }

        before do
          Fabricate(:status, reblog: status, account: sender, uri: 'bar')
        end

        it 'deletes the reblog by uri' do
          subject.perform
          expect(sender.reblogged?(status)).to be false
        end
      end
    end

    context 'with Accept' do
      let(:recipient) { Fabricate(:account) }
      let(:object_json) do
        {
          id: 'bar',
          type: 'Accept',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: 'follow-to-revoke',
        }
      end

      before do
        recipient.follow!(sender, uri: 'follow-to-revoke')
      end

      it 'deletes follow from recipient to sender' do
        subject.perform
        expect(recipient.following?(sender)).to be false
      end

      it 'creates a follow request from recipient to sender' do
        subject.perform
        expect(recipient.requested?(sender)).to be true
      end
    end

    context 'with Block' do
      let(:recipient) { Fabricate(:account) }

      let(:object_json) do
        {
          id: 'bar',
          type: 'Block',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: ActivityPub::TagManager.instance.uri_for(recipient),
        }
      end

      before do
        sender.block!(recipient, uri: 'bar')
      end

      it 'deletes block from sender to recipient' do
        subject.perform
        expect(sender.blocking?(recipient)).to be false
      end

      context 'with only object uri' do
        let(:object_json) { 'bar' }

        it 'deletes block from sender to recipient' do
          subject.perform
          expect(sender.blocking?(recipient)).to be false
        end
      end
    end

    context 'with Follow' do
      let(:recipient) { Fabricate(:account) }

      let(:object_json) do
        {
          id: 'bar',
          type: 'Follow',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: ActivityPub::TagManager.instance.uri_for(recipient),
        }
      end

      before do
        sender.follow!(recipient, uri: 'bar')
      end

      it 'deletes follow from sender to recipient' do
        subject.perform
        expect(sender.following?(recipient)).to be false
      end

      it 'deletes follow from sender to recipient when has friend' do
        friend = Fabricate(:friend_domain, domain: sender.domain, passive_state: :accepted)
        subject.perform
        expect(sender.following?(recipient)).to be false
        expect(friend.they_are_accepted?).to be true
      end

      context 'with only object uri' do
        let(:object_json) { 'bar' }

        it 'deletes follow from sender to recipient' do
          subject.perform
          expect(sender.following?(recipient)).to be false
        end
      end

      context 'when for a friend' do
        let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }
        let!(:friend) { Fabricate(:friend_domain, domain: 'abc.com', passive_state: :accepted, passive_follow_activity_id: 'bar') }
        let(:object_json) do
          {
            id: 'bar',
            type: 'Follow',
            actor: ActivityPub::TagManager.instance.uri_for(sender),
            object: 'https://www.w3.org/ns/activitystreams#Public',
          }
        end

        it 'deletes follow from this server to friend' do
          subject.perform
          expect(friend.reload.they_are_idle?).to be true
          expect(friend.passive_follow_activity_id).to be_nil
        end

        it 'when my server is pending' do
          friend.update(active_state: :pending)
          subject.perform
          expect(friend.reload.they_are_idle?).to be true
          expect(friend.i_am_idle?).to be true
        end

        it 'when my server is accepted' do
          friend.update(active_state: :accepted)
          subject.perform
          expect(friend.reload.they_are_idle?).to be true
          expect(friend.i_am_idle?).to be true
        end
      end
    end

    context 'with Like' do
      let(:status) { Fabricate(:status) }

      let(:object_json) do
        {
          id: 'bar',
          type: 'Like',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          object: ActivityPub::TagManager.instance.uri_for(status),
        }
      end

      before do
        Fabricate(:favourite, account: sender, status: status)
      end

      it 'deletes favourite from sender to status' do
        subject.perform
        expect(sender.favourited?(status)).to be false
      end
    end
  end
end
