# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NgRule do
  describe '#copy!' do
    let(:original) { Fabricate(:ng_rule, account_domain: 'foo.bar', account_avatar_state: :needed, status_text: 'ohagi', status_mention_threshold: 5, status_allow_follower_mention: false) }
    let(:copied) { original.copy! }

    it 'saves safely' do
      expect { copied.save! }.to_not raise_error
      expect(copied.reload.id).to_not eq original.id
    end

    it 'saves specified rules' do
      expect(copied.account_domain).to eq 'foo.bar'
      expect(copied.account_avatar_state.to_sym).to eq :needed
      expect(copied.status_text).to eq 'ohagi'
      expect(copied.status_mention_threshold).to eq 5
      expect(copied.status_allow_follower_mention).to be false
    end

    it 'saves default rules' do
      expect(copied.account_header_state.to_sym).to eq :optional
      expect(copied.status_spoiler_text).to eq ''
      expect(copied.status_reference_threshold).to eq(-1)
    end
  end
end
