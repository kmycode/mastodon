# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FavouriteService, type: :service do
  subject { described_class.new }

  let(:sender) { Fabricate(:account, username: 'alice') }

  describe 'local' do
    let(:bob)    { Fabricate(:account) }
    let(:status) { Fabricate(:status, account: bob) }

    before do
      subject.call(sender, status)
    end

    it 'creates a favourite' do
      expect(status.favourites.first).to_not be_nil
    end
  end

  describe 'remote ActivityPub' do
    let(:bob)    { Fabricate(:account, protocol: :activitypub, username: 'bob', domain: 'example.com', inbox_url: 'http://example.com/inbox') }
    let(:status) { Fabricate(:status, account: bob) }

    before do
      stub_request(:post, 'http://example.com/inbox').to_return(status: 200, body: '', headers: {})
      subject.call(sender, status)
    end

    it 'creates a favourite' do
      expect(status.favourites.first).to_not be_nil
    end

    it 'sends a like activity', :sidekiq_inline do
      expect(a_request(:post, 'http://example.com/inbox')).to have_been_made.once
    end
  end

  context 'with ng rule' do
    let(:status) { Fabricate(:status) }
    let(:sender) { Fabricate(:account) }

    context 'when rule matches' do
      before do
        Fabricate(:ng_rule, reaction_type: ['favourite'], reaction_action: :reject)
      end

      it 'does not favourite' do
        expect { subject.call(sender, status) }.to raise_error Mastodon::ValidationError
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'when rule does not match' do
      before do
        Fabricate(:ng_rule, account_display_name: 'else', reaction_type: ['favourite'], reaction_action: :reject)
      end

      it 'favourites' do
        expect { subject.call(sender, status) }.to_not raise_error
        expect(sender.favourited?(status)).to be true
      end
    end
  end
end
