# frozen_string_literal: true

require 'rails_helper'

describe Admin::NgRule do
  shared_examples 'matches rule' do |reason|
    it 'matches and history is added' do
      expect(subject).to be false

      history = NgRuleHistory.order(id: :desc).find_by(ng_rule: ng_rule)
      expect(history).to_not be_nil
      expect(history.account_id).to eq account.id
      expect(history.reason).to eq reason
      expect(history.uri).to eq uri
    end
  end

  shared_examples 'does not match rule' do
    it 'does not match and history is not added' do
      expect(subject).to be true

      history = NgRuleHistory.order(id: :desc).find_by(ng_rule: ng_rule)
      expect(history).to be_nil
    end
  end

  shared_examples 'check all states' do |reason, results|
    context 'when rule state is optional' do
      let(:state) { :optional }

      it_behaves_like results[0] ? 'does not match rule' : 'matches rule', reason
    end

    context 'when rule state is needed' do
      let(:state) { :needed }

      it_behaves_like results[1] ? 'does not match rule' : 'matches rule', reason
    end

    context 'when rule state is no_needed' do
      let(:state) { :no_needed }

      it_behaves_like results[2] ? 'does not match rule' : 'matches rule', reason
    end
  end

  let(:uri) { 'https://example.com/operation' }

  describe '#check_account_or_record!' do
    subject { described_class.new(ng_rule, account).check_account_or_record! }

    context 'when unmatch rule' do
      let(:ng_rule) { Fabricate(:ng_rule, account_note: 'assur', account_include_local: true) }
      let(:account) { Fabricate(:account, domain: 'example.com', uri: uri) }

      it_behaves_like 'does not match rule'
    end

    context 'with domain rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: uri) }
      let(:ng_rule) { Fabricate(:ng_rule, account_domain: '?example\..*') }

      it_behaves_like 'matches rule', 'account'
    end

    context 'with note rule' do
      let(:uri) { '' }
      let(:account) { Fabricate(:account, note: 'ohagi is good') }
      let(:ng_rule) { Fabricate(:ng_rule, account_note: 'ohagi', account_include_local: true) }

      it_behaves_like 'matches rule', 'account'
    end

    context 'with display name rule' do
      let(:uri) { '' }
      let(:account) { Fabricate(:account, display_name: '') }
      let(:ng_rule) { Fabricate(:ng_rule, account_display_name: "?^$\r\n?[a-z0-9]{10}", account_include_local: true) }

      it_behaves_like 'matches rule', 'account'
    end

    context 'with field name rule' do
      let(:account) { Fabricate(:account, fields_attributes: { '0' => { name: 'Name', value: 'Value' } }, domain: 'example.com', uri: uri) }
      let(:ng_rule) { Fabricate(:ng_rule, account_field_name: 'Name') }

      it_behaves_like 'matches rule', 'account'
    end

    context 'with field value rule' do
      let(:account) { Fabricate(:account, fields_attributes: { '0' => { name: 'Name', value: 'Value' } }, domain: 'example.com', uri: uri) }
      let(:ng_rule) { Fabricate(:ng_rule, account_field_value: 'Value') }

      it_behaves_like 'matches rule', 'account'
    end

    context 'with avatar rule' do
      context 'when avatar is not set' do
        let(:account) { Fabricate(:account, domain: 'example.com', uri: uri) }
        let(:ng_rule) { Fabricate(:ng_rule, account_avatar_state: state) }

        it_behaves_like 'check all states', 'account', [false, true, false]
      end

      context 'when avatar is set' do
        let(:account) { Fabricate(:account, avatar: fixture_file_upload('avatar.gif', 'image/gif'), domain: 'example.com', uri: uri) }
        let(:ng_rule) { Fabricate(:ng_rule, account_avatar_state: state) }

        it_behaves_like 'check all states', 'account', [false, false, true]
      end
    end
  end

  describe '#check_status_or_record!' do
    subject do
      opts = { reaction_type: 'create' }.merge(options)
      described_class.new(ng_rule, account, **opts).check_status_or_record!
    end

    context 'when status matches but account does not match' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, text: 'this is a spam' } }
      let(:ng_rule) { Fabricate(:ng_rule, account_domain: 'ohagi.jp', status_text: 'spam') }

      it_behaves_like 'does not match rule'
    end

    context 'when account matches but status does not match' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, text: 'this is a spam' } }
      let(:ng_rule) { Fabricate(:ng_rule, account_domain: 'example.com', status_text: 'span') }

      it_behaves_like 'does not match rule'
    end

    context 'with text rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, text: 'this is a spam' } }
      let(:ng_rule) { Fabricate(:ng_rule, status_text: 'spam') }

      it_behaves_like 'matches rule', 'status'

      it 'records as public' do
        subject

        history = NgRuleHistory.order(id: :desc).find_by(ng_rule: ng_rule)
        expect(history.hidden).to be false
      end
    end

    context 'with visibility rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:ng_rule) { Fabricate(:ng_rule, status_visibility: ['public', 'public_unlisted']) }

      context 'with public visibility' do
        let(:options) { { uri: uri, visibility: 'public' } }

        it_behaves_like 'matches rule', 'status'
      end

      context 'with unlisted visibility' do
        let(:options) { { uri: uri, visibility: 'unlisted' } }

        it_behaves_like 'does not match rule', 'status'
      end
    end

    context 'with searchability rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:ng_rule) { Fabricate(:ng_rule, status_searchability: ['public', 'public_unlisted']) }

      context 'with public searchability' do
        let(:options) { { uri: uri, searchability: 'public' } }

        it_behaves_like 'matches rule', 'status'
      end

      context 'with private searchability' do
        let(:options) { { uri: uri, searchability: 'private' } }

        it_behaves_like 'does not match rule', 'status'
      end

      context 'with unset' do
        let(:options) { { uri: uri, searchability: nil } }

        it_behaves_like 'does not match rule', 'status'
      end
    end

    context 'with reply rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, reply: false } }
      let(:ng_rule) { Fabricate(:ng_rule, status_reply_state: :no_needed) }

      it_behaves_like 'matches rule', 'status'
    end

    context 'with media size rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, media_count: 5 } }
      let(:ng_rule) { Fabricate(:ng_rule, status_media_threshold: 4) }

      it_behaves_like 'matches rule', 'status'
    end

    context 'with mention size rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, mention_count: 5 } }
      let(:ng_rule) { Fabricate(:ng_rule, status_mention_threshold: 4, status_allow_follower_mention: false) }

      it_behaves_like 'matches rule', 'status'

      context 'when mention to stranger' do
        let(:options) { { uri: uri, mention_count: 5, mention_to_following: false } }
        let(:ng_rule) { Fabricate(:ng_rule, status_mention_threshold: 4, status_allow_follower_mention: true) }

        it_behaves_like 'matches rule', 'status'
      end

      context 'when mention to follower' do
        let(:options) { { uri: uri, mention_count: 5, mention_to_following: true } }
        let(:ng_rule) { Fabricate(:ng_rule, status_mention_threshold: 4, status_allow_follower_mention: true) }

        it_behaves_like 'does not match rule', 'status'
      end
    end

    context 'with private privacy' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, text: 'this is a spam', visibility: 'private' } }
      let(:ng_rule) { Fabricate(:ng_rule, status_text: 'spam', status_visibility: %w(private)) }

      it 'records as hidden' do
        expect(subject).to be false

        history = NgRuleHistory.order(id: :desc).find_by(ng_rule: ng_rule)
        expect(history).to_not be_nil
        expect(history.account_id).to eq account.id
        expect(history.reason).to eq 'status'
        expect(history.uri).to be_nil
        expect(history.hidden).to be true
        expect(history.text).to be_nil
      end
    end
  end

  describe '#check_reaction_or_record!' do
    subject do
      described_class.new(ng_rule, account, **options).check_reaction_or_record!
    end

    context 'when account matches but reaction does not match' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, recipient: Fabricate(:account), reaction_type: 'favourite' } }
      let(:ng_rule) { Fabricate(:ng_rule, account_domain: 'example.com', status_text: 'span', reaction_type: ['reblog']) }

      it_behaves_like 'does not match rule'
    end

    context 'with reaction type rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, recipient: Fabricate(:account), reaction_type: 'favourite' } }
      let(:ng_rule) { Fabricate(:ng_rule, reaction_type: ['favourite', 'follow']) }

      it_behaves_like 'matches rule', 'reaction'

      context 'when reblog' do
        let(:options) { { uri: uri, recipient: Fabricate(:account), reaction_type: 'reblog' } }

        it_behaves_like 'does not match rule'
      end
    end

    context 'with emoji reaction shortcode rule' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
      let(:options) { { uri: uri, recipient: Fabricate(:account), reaction_type: 'emoji_reaction', emoji_reaction_name: 'ohagi' } }
      let(:ng_rule) { Fabricate(:ng_rule, reaction_type: ['emoji_reaction'], emoji_reaction_name: 'ohagi') }

      it_behaves_like 'matches rule', 'reaction'
    end
  end
end
