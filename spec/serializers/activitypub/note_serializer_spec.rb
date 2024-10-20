# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::NoteSerializer do
  subject { serialized_record_json(parent, described_class, adapter: ActivityPub::Adapter) }

  let(:visibility) { :public }
  let(:searchability) { :public }
  let!(:account) { Fabricate(:account) }
  let!(:other) { Fabricate(:account) }
  let!(:parent) { Fabricate(:status, account: account, visibility: visibility, searchability: searchability, language: 'zh-TW') }
  let!(:reply_by_account_first) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_next) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_other_first) { Fabricate(:status, account: other, thread: parent, visibility: :public) }
  let!(:reply_by_account_third) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_visibility_direct) { Fabricate(:status, account: account, thread: parent, visibility: :direct) }
  let!(:referred) { nil }
  let!(:quote) { nil }

  before do
    parent.references << referred if referred.present?
    if quote.present?
      parent.references << quote
      parent.quote = quote
    end
  end

  it 'has the expected shape and replies collection' do
    expect(subject).to include({
      '@context' => include('https://www.w3.org/ns/activitystreams'),
      'type' => 'Note',
      'attributedTo' => ActivityPub::TagManager.instance.uri_for(account),
      'contentMap' => include({
        'zh-TW' => a_kind_of(String),
      }),
      'replies' => replies_collection_values,
    })
  end

  def replies_collection_values
    include(
      'type' => eql('Collection'),
      'first' => include(
        'type' => eql('CollectionPage'),
        'items' => reply_items
      )
    )
  end

  def reply_items
    include(reply_by_account_first.uri, reply_by_account_next.uri, reply_by_account_third.uri) # Public self replies
      .and(not_include(reply_by_other_first.uri)) # Replies from others
      .and(not_include(reply_by_account_visibility_direct.uri)) # Replies with direct visibility
  end

  it 'send as public visibility' do
    expect(subject['to']).to include 'https://www.w3.org/ns/activitystreams#Public'
  end

  context 'when public_unlisted visibility' do
    let(:visibility) { :public_unlisted }

    it 'send as unlisted visibility' do
      expect(subject['to']).to_not include 'https://www.w3.org/ns/activitystreams#Public'
    end
  end

  it 'send as public searchability' do
    expect(subject['searchableBy']).to include 'https://www.w3.org/ns/activitystreams#Public'
  end

  context 'when public_unlisted searchability' do
    let(:searchability) { :public_unlisted }

    it 'send as private searchability' do
      expect(subject['searchableBy']).to_not include 'https://www.w3.org/ns/activitystreams#Public'
    end
  end

  context 'when direct searchability' do
    let(:searchability) { :direct }

    it 'send as direct searchability' do
      expect(subject['searchableBy']).to include "https://cb6e6126.ngrok.io/users/#{account.username}"
    end
  end

  context 'when has a reference' do
    let(:referred) { Fabricate(:status) }

    it 'has a references collection' do
      expect(subject['references']['type']).to eql('Collection')
    end

    it 'has a references collection with a first Page' do
      expect(subject['references']['first']['type']).to eql('CollectionPage')
    end

    it 'has as reference' do
      expect(subject['quoteUri']).to be_nil
      expect(subject['references']['first']['items']).to include referred.uri
    end
  end

  context 'when has a quote' do
    let(:quote) { Fabricate(:status) }

    it 'has a quote as transitional type' do
      expect(subject['quoteUri']).to eq ActivityPub::TagManager.instance.uri_for(quote)
    end

    it 'has a quote as feb-e232 object link' do
      tag = subject['tag'].detect { |t| t['type'] == 'Link' }
      expect(tag).to_not be_nil
      expect(tag['mediaType']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
      expect(tag['href']).to eq ActivityPub::TagManager.instance.uri_for(quote)
    end
  end
end
