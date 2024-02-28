# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivateRemoteStatusesService, type: :service do
  subject { described_class.new.call(sender) }

  let(:sender) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
  let(:alice) { Fabricate(:account) }
  let!(:pending_status) { Fabricate(:pending_status, account: sender, fetch_account: alice, uri: 'https://example.com/note') }

  let(:payload) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: pending_status.uri,
      attributedTo: sender.uri,
      type: 'Note',
      content: 'Lorem ipsum',
      to: 'https://www.w3.org/ns/activitystreams#Public',
      tag: [
        {
          type: 'Mention',
          href: ActivityPub::TagManager.instance.uri_for(alice),
        },
      ],
    }
  end
  let(:json) { Oj.dump(payload) }

  before do
    stub_request(:get, 'https://example.com/note').to_return(status: 200, body: json, headers: { 'Content-Type': 'application/activity+json' })
  end

  context 'when has a pending status' do
    before do
      subject
    end

    it 'original status is fetched', :sidekiq_inline do
      status = sender.statuses.first

      expect(status).to_not be_nil
      expect(status.text).to eq 'Lorem ipsum'
    end

    it 'pending request is removed' do
      expect { pending_status.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context 'when target_account is suspended' do
    before do
      alice.suspend!
      subject
    end

    it 'original status is not fetched', :sidekiq_inline do
      status = sender.statuses.first

      expect(status).to be_nil
    end

    it 'pending request is removed' do
      expect { pending_status.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
