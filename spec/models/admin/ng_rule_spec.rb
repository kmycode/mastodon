# frozen_string_literal: true

require 'rails_helper'

describe Admin::NgRule do
  shared_examples 'matches rule' do |reason|
    it 'matches' do
      expect(subject).to be true
    end

    it 'history is set' do
      subject

      history = NgRuleHistory.order(id: :desc).find_by(ng_rule: ng_rule)
      expect(history).to_not be_nil
      expect(history.account_id).to eq account.id
      expect(history.reason.to_sym).to eq reason
      expect(history.uri).to eq uri
    end
  end

  let(:uri) { 'https://example.com/operation' }

  describe '#account_match_and_record!' do
    subject { described_class.new(ng_rule, account).account_match_and_record!(uri) }

    context 'when domain is set' do
      let(:account) { Fabricate(:account, domain: 'example.com') }
      let(:ng_rule) { Fabricate(:ng_rule, account_domain: '?example\..*') }

      it_behaves_like 'matches rule', :account_domain
    end
  end
end
