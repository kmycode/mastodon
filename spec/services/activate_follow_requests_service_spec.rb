# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivateFollowRequestsService, type: :service do
  subject { described_class.new.call(sender) }

  let(:sender) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }
  let(:alice) { Fabricate(:account) }
  let!(:follow_request) { Fabricate(:pending_follow_request, account: sender, target_account: alice) }

  before do
    allow(LocalNotificationWorker).to receive(:perform_async).and_return(nil)
  end

  context 'when has a silent follow request' do
    before do
      subject
    end

    it 'follows immediately' do
      follow = Follow.find_by(account: sender, target_account: alice)
      expect(follow).to_not be_nil
      expect(LocalNotificationWorker).to have_received(:perform_async).with(alice.id, follow.id, 'Follow', 'follow')

      new_follow_request = FollowRequest.find_by(account: sender, target_account: alice)
      expect(new_follow_request).to be_nil
    end

    it 'pending request is removed' do
      expect { follow_request.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context 'when target_account is locked' do
    before do
      alice.update!(locked: true)
      subject
    end

    it 'enable a follow request' do
      new_follow_request = FollowRequest.find_by(account: sender, target_account: alice)

      expect(sender.following?(alice)).to be false

      expect(new_follow_request).to_not be_nil
      expect(new_follow_request.uri).to eq follow_request.uri
      expect(LocalNotificationWorker).to have_received(:perform_async).with(alice.id, new_follow_request.id, 'FollowRequest', 'follow_request')
    end

    it 'pending request is removed' do
      expect { follow_request.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
