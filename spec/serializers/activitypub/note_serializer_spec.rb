# frozen_string_literal: true

require 'rails_helper'

describe ActivityPub::NoteSerializer do
  subject { JSON.parse(@serialization.to_json) }

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
  let!(:referred2) { nil }

  before(:each) do
    parent.references << referred if referred.present?
    parent.references << referred2 if referred2.present?
    @serialization = ActiveModelSerializers::SerializableResource.new(parent, serializer: described_class, adapter: ActivityPub::Adapter)
  end

  it 'has the expected shape' do
    expect(subject).to include({
      '@context' => include('https://www.w3.org/ns/activitystreams'),
      'type' => 'Note',
      'attributedTo' => ActivityPub::TagManager.instance.uri_for(account),
      'contentMap' => include({
        'zh-TW' => a_kind_of(String),
      }),
    })
  end

  it 'has a replies collection' do
    expect(subject['replies']['type']).to eql('Collection')
  end

  it 'has a replies collection with a first Page' do
    expect(subject['replies']['first']['type']).to eql('CollectionPage')
  end

  it 'includes public self-replies in its replies collection' do
    expect(subject['replies']['first']['items']).to include(reply_by_account_first.uri, reply_by_account_next.uri, reply_by_account_third.uri)
  end

  it 'does not include replies from others in its replies collection' do
    expect(subject['replies']['first']['items']).to_not include(reply_by_other_first.uri)
  end

  it 'does not include replies with direct visibility in its replies collection' do
    expect(subject['replies']['first']['items']).to_not include(reply_by_account_visibility_direct.uri)
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

  context 'when has quote but no_convert setting' do
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
end
