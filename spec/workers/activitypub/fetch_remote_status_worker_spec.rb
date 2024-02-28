# frozen_string_literal: true

require 'rails_helper'

describe ActivityPub::FetchRemoteStatusWorker do
  subject { described_class.new }

  let(:sender) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
  let(:payload) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'https://example.com/note',
      attributedTo: sender.uri,
      type: 'Note',
      content: 'Lorem ipsum',
      to: 'https://www.w3.org/ns/activitystreams#Public',
      tag: [
        {
          type: 'Mention',
          href: ActivityPub::TagManager.instance.uri_for(Fabricate(:account)),
        },
      ],
    }
  end
  let(:json) { Oj.dump(payload) }

  before do
    stub_request(:get, 'https://example.com/note').to_return(status: 200, body: json, headers: { 'Content-Type': 'application/activity+json' })
  end

  describe '#perform' do
    it 'original status is fetched' do
      subject.perform('https://example.com/note', sender.id, Fabricate(:account).id)

      status = sender.statuses.first

      expect(status).to_not be_nil
      expect(status.text).to eq 'Lorem ipsum'
    end
  end
end
