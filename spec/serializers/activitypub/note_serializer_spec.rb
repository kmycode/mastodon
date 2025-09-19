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

  before do
    parent.references << referred if referred.present?
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
      'context' => ActivityPub::TagManager.instance.uri_for(parent.conversation),
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
      expect(subject['references']['first']['items']).to include referred.uri
    end
  end

  context 'with a quote' do
    let(:quoted_status) { Fabricate(:status) }
    let!(:quote) { Fabricate(:quote, status: parent, quoted_status: quoted_status, state: :accepted) }

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        'quoteUri' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        '_misskey_quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        'quoteAuthorization' => ActivityPub::TagManager.instance.approval_uri_for(quote),
      })
    end
  end

  context 'with a pending quote' do
    let(:quoted_account) { Fabricate(:account) }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: parent, quoted_status: quoted_status, state: :accepted) }

    shared_examples 'quote is authorized' do
      it 'has the expected shape' do
        expect(subject).to include({
          'type' => 'Note',
          'quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
          'quoteUri' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
          '_misskey_quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
          'quoteAuthorization' => ActivityPub::TagManager.instance.approval_uri_for(quote),
        })
      end
    end

    shared_examples 'quote is not authorized' do
      it 'has the expected shape' do
        expect(subject).to include({
          'type' => 'Note',
          'quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
          'quoteUri' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
          '_misskey_quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        })
        expect(subject).to_not have_key('quoteAuthorization')
      end
    end

    it_behaves_like 'quote is authorized'

    context 'when quote is pending' do
      let(:quote) { Fabricate(:quote, status: parent, quoted_status: quoted_status, state: :pending) }

      it_behaves_like 'quote is not authorized'
    end

    context 'when quote is from misskey and approval_uri is nil' do
      let(:quoted_account) { Fabricate(:account, uri: 'https://example.com/actor', domain: 'example.com') }

      before { Fabricate(:instance_info, domain: 'example.com', software: 'misskey') }

      it_behaves_like 'quote is not authorized'
    end

    context 'when quote is from misskey and approval_uri is nil, auto_accept_legacy_quotes is enabled' do
      let(:quoted_account) { Fabricate(:account, uri: 'https://example.com/actor', domain: 'example.com') }

      before do
        Fabricate(:instance_info, domain: 'example.com', software: 'misskey')
        Setting.auto_accept_legacy_quotes = true
      end

      it_behaves_like 'quote is authorized'
    end

    context 'when quote is from mastodon and approval_uri is nil' do
      let(:quoted_account) { Fabricate(:account, uri: 'https://example.com/actor', domain: 'example.com') }

      before { Fabricate(:instance_info, domain: 'example.com', software: 'mastodon') }

      it_behaves_like 'quote is not authorized'
    end

    context 'when quote is from mastodon and approval_uri is nil, auto_accept_legacy_quotes is enabled' do
      let(:quoted_account) { Fabricate(:account, uri: 'https://example.com/actor', domain: 'example.com') }

      before do
        Fabricate(:instance_info, domain: 'example.com', software: 'mastodon')
        Setting.auto_accept_legacy_quotes = true
      end

      it_behaves_like 'quote is not authorized'
    end
  end

  context 'with a quote policy', feature: :outgoing_quotes do
    let(:parent) { Fabricate(:status, quote_approval_policy: Status::QUOTE_APPROVAL_POLICY_FLAGS[:followers] << 16) }

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'interactionPolicy' => a_hash_including(
          'canQuote' => a_hash_including(
            'automaticApproval' => [ActivityPub::TagManager.instance.followers_uri_for(parent.account)]
          )
        ),
      })
    end
  end
end
