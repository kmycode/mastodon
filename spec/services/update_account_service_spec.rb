# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateAccountService, type: :service do
  subject { described_class.new }

  describe 'switching form locked to unlocked accounts' do
    let(:account) { Fabricate(:account, locked: true) }
    let(:alice)   { Fabricate(:account) }
    let(:bob)     { Fabricate(:account) }
    let(:eve)     { Fabricate(:account) }
    let(:ohagi)   { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }

    before do
      bob.touch(:silenced_at)
      account.mute!(eve)
      Fabricate(:domain_block, domain: 'example.com', reject_straight_follow: true)

      FollowService.new.call(alice, account)
      FollowService.new.call(bob, account)
      FollowService.new.call(eve, account)
      FollowService.new.call(ohagi, account)

      subject.call(account, { locked: false })
    end

    it 'auto-accepts pending follow requests' do
      expect(alice.following?(account)).to be true
      expect(alice.requested?(account)).to be false
    end

    it 'does not auto-accept pending follow requests from silenced users' do
      expect(bob.following?(account)).to be false
      expect(bob.requested?(account)).to be true
    end

    it 'auto-accepts pending follow requests from muted users so as to not leak mute' do
      expect(eve.following?(account)).to be true
      expect(eve.requested?(account)).to be false
    end

    it 'does not auto-accept pending follow requests from blocking straight follow domains' do
      expect(ohagi.following?(account)).to be false
      expect(ohagi.requested?(account)).to be true
    end
  end
end
