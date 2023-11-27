# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Delete do
  let(:sender) { Fabricate(:account, domain: 'example.com') }
  let(:status) { Fabricate(:status, account: sender, uri: 'foobar') }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Delete',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: ActivityPub::TagManager.instance.uri_for(status),
      signature: 'foo',
    }.with_indifferent_access
  end

  describe '#perform' do
    subject { described_class.new(json, sender) }

    before do
      subject.perform
    end

    it 'deletes sender\'s status' do
      expect(Status.find_by(id: status.id)).to be_nil
    end
  end

  context 'when the status has been reblogged' do
    describe '#perform' do
      subject { described_class.new(json, sender) }

      let!(:reblogger) { Fabricate(:account) }
      let!(:follower)  { Fabricate(:account, username: 'follower', protocol: :activitypub, domain: 'example.com', inbox_url: 'http://example.com/inbox') }
      let!(:reblog)    { Fabricate(:status, account: reblogger, reblog: status) }

      before do
        stub_request(:post, 'http://example.com/inbox').to_return(status: 200)
        follower.follow!(reblogger)
        subject.perform
      end

      it 'deletes sender\'s status' do
        expect(Status.find_by(id: status.id)).to be_nil
      end

      it 'sends delete activity to followers of rebloggers' do
        expect(a_request(:post, 'http://example.com/inbox')).to have_been_made.once
      end
    end
  end

  context 'when the status has been reported' do
    describe '#perform' do
      subject { described_class.new(json, sender) }

      let!(:reporter) { Fabricate(:account) }

      before do
        reporter.reports.create!(target_account: status.account, status_ids: [status.id], forwarded: false)
        subject.perform
      end

      it 'marks the status as deleted' do
        expect(Status.find_by(id: status.id)).to be_nil
      end

      it 'actually keeps a copy for inspection' do
        expect(Status.with_discarded.find_by(id: status.id)).to_not be_nil
      end
    end
  end

  context 'when the status is limited post and has conversation' do
    subject { described_class.new(json, sender) }

    let(:conversation) { Fabricate(:conversation, ancestor_status: status) }

    before do
      status.update(conversation: conversation, visibility: :limited)
      status.mentions << Fabricate(:mention, silent: true, account: Fabricate(:account, protocol: :activitypub, domain: 'example.com', inbox_url: 'https://example.com/actor/inbox', shared_inbox_url: 'https://example.com/inbox'))
      status.save
      stub_request(:post, 'https://example.com/inbox').to_return(status: 200)
      subject.perform
    end

    it 'forwards to parent status holder' do
      expect(a_request(:post, 'https://example.com/inbox').with(body: hash_including({
        type: 'Delete',
        signature: 'foo',
      }))).to have_been_made.once
    end
  end

  context 'when given a friend server' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:friend_domain, domain: 'abc.com', inbox_url: 'https://abc.com/inbox', passive_state: :accepted)
      stub_request(:post, 'https://abc.com/inbox')
    end

    let(:sender) { Fabricate(:account, domain: 'abc.com', url: 'https://abc.com/#actor') }

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Delete',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: 'https://www.w3.org/ns/activitystreams#Public',
      }.with_indifferent_access
    end

    it 'marks the friend as deleted' do
      subject.perform
      expect(FriendDomain.find_by(domain: 'abc.com')).to be_nil
    end
  end
end
