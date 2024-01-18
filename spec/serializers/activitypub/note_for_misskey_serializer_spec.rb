# frozen_string_literal: true

require 'rails_helper'

describe ActivityPub::NoteForMisskeySerializer do
  subject { JSON.parse(serialization.to_json) }

  let(:serialization) { ActiveModelSerializers::SerializableResource.new(parent, serializer: described_class, adapter: ActivityPub::Adapter) }
  let!(:account) { Fabricate(:account) }
  let!(:other) { Fabricate(:account) }
  let!(:parent) { Fabricate(:status, account: account, visibility: :unlisted, searchability: :private) }
  let!(:reply_by_account_first) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_next) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_other_first) { Fabricate(:status, account: other, thread: parent, visibility: :public) }
  let!(:reply_by_account_third) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_visibility_direct) { Fabricate(:status, account: account, thread: parent, visibility: :direct) }

  before do
    account.user.settings.update(reject_unlisted_subscription: 'true')
  end

  it 'has a Note type' do
    expect(subject['type']).to eql('Note')
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

  it 'has private visibility' do
    expect(subject['to']).to_not include('https://www.w3.org/ns/activitystreams#Public')
    expect(subject['to'].any? { |to| to.end_with?("#{account.username}/followers") }).to be true
    expect(subject['cc']).to_not include('https://www.w3.org/ns/activitystreams#Public')
  end
end
