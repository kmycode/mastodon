# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::FetchReferencesService, type: :service do
  subject { described_class.new.call(status.account, payload) }

  let(:actor)          { Fabricate(:account, domain: 'example.com', uri: 'http://example.com/account') }
  let(:status)         { Fabricate(:status, account: actor) }
  let(:collection_uri) { 'http://example.com/references/1' }

  let(:items) do
    [
      'http://example.com/self-references-1',
      'http://example.com/self-references-2',
      'http://example.com/self-references-3',
      'http://other.com/other-references-1',
      'http://other.com/other-references-2',
      'http://other.com/other-references-3',
      'http://example.com/self-references-4',
      'http://example.com/self-references-5',
      'http://example.com/self-references-6',
      'http://example.com/self-references-7',
      'http://example.com/self-references-8',
    ]
  end

  let(:payload) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      type: 'Collection',
      id: collection_uri,
      items: items,
    }.with_indifferent_access
  end

  describe '#call' do
    context 'when the payload is a Collection with inlined replies' do
      context 'when there is a single reference, with the array compacted away' do
        let(:items) { 'http://example.com/self-references-1' }

        it 'a item is returned' do
          expect(subject).to eq ['http://example.com/self-references-1']
        end
      end

      context 'when passing the collection itself' do
        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end

      context 'when passing the URL to the collection' do
        subject { described_class.new.call(status, collection_uri) }

        before do
          stub_request(:get, collection_uri).to_return(status: 200, body: Oj.dump(payload), headers: { 'Content-Type': 'application/activity+json' })
        end

        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end
    end

    context 'when the payload is an OrderedCollection with inlined references' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          type: 'OrderedCollection',
          id: collection_uri,
          orderedItems: items,
        }.with_indifferent_access
      end

      context 'when passing the collection itself' do
        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end

      context 'when passing the URL to the collection' do
        subject { described_class.new.call(status, collection_uri) }

        before do
          stub_request(:get, collection_uri).to_return(status: 200, body: Oj.dump(payload), headers: { 'Content-Type': 'application/activity+json' })
        end

        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end
    end

    context 'when the payload is a paginated Collection with inlined references' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          type: 'Collection',
          id: collection_uri,
          first: {
            type: 'CollectionPage',
            partOf: collection_uri,
            items: items,
          },
        }.with_indifferent_access
      end

      context 'when passing the collection itself' do
        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end

      context 'when passing the URL to the collection' do
        subject { described_class.new.call(status, collection_uri) }

        before do
          stub_request(:get, collection_uri).to_return(status: 200, body: Oj.dump(payload), headers: { 'Content-Type': 'application/activity+json' })
        end

        it 'first 8 items are returned' do
          expect(subject).to eq items.take(8)
        end
      end
    end
  end
end
