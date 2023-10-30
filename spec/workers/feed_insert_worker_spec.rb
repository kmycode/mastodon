# frozen_string_literal: true

require 'rails_helper'

describe FeedInsertWorker do
  subject { described_class.new }

  def notify?(account, type, activity_id)
    Notification.exists?(account: account, type: type, activity_id: activity_id)
  end

  describe 'perform' do
    let(:follower) { Fabricate(:account) }
    let(:status) { Fabricate(:status) }

    context 'when there are no records' do
      it 'skips push with missing status' do
        instance = instance_double(FeedManager, push_to_home: nil)
        allow(FeedManager).to receive(:instance).and_return(instance)
        result = subject.perform(nil, follower.id)

        expect(result).to be true
        expect(instance).to_not have_received(:push_to_home)
      end

      it 'skips push with missing account' do
        instance = instance_double(FeedManager, push_to_home: nil)
        allow(FeedManager).to receive(:instance).and_return(instance)
        result = subject.perform(status.id, nil)

        expect(result).to be true
        expect(instance).to_not have_received(:push_to_home)
      end
    end

    context 'when there are real records' do
      it 'skips the push when there is a filter' do
        instance = instance_double(FeedManager, push_to_home: nil, filter?: true)
        allow(FeedManager).to receive(:instance).and_return(instance)
        result = subject.perform(status.id, follower.id)

        expect(result).to be_nil
        expect(instance).to_not have_received(:push_to_home)
      end

      it 'pushes the status onto the home timeline without filter' do
        instance = instance_double(FeedManager, push_to_home: nil, filter?: false)
        allow(FeedManager).to receive(:instance).and_return(instance)
        result = subject.perform(status.id, follower.id)

        expect(result).to be_nil
        expect(instance).to have_received(:push_to_home).with(follower, status, update: nil)
      end
    end

    context 'with notification' do
      it 'skips notification when unset' do
        subject.perform(status.id, follower.id)
        expect(notify?(follower, 'status', status.id)).to be false
      end

      it 'pushes notification when read status is set' do
        Fabricate(:follow, account: follower, target_account: status.account, notify: true)

        subject.perform(status.id, follower.id)
        expect(notify?(follower, 'status', status.id)).to be true
      end

      it 'skips notification when the account is registered list but not notify' do
        follower.follow!(status.account)
        list = Fabricate(:list, account: follower)
        Fabricate(:list_account, list: list, account: status.account)

        subject.perform(status.id, list.id, 'list')

        list_status = ListStatus.find_by(list: list, status: status)

        expect(list_status).to be_nil
      end

      it 'pushes notification when the account is registered list' do
        follower.follow!(status.account)
        list = Fabricate(:list, account: follower, notify: true)
        Fabricate(:list_account, list: list, account: status.account)

        subject.perform(status.id, list.id, 'list')
        list_status = ListStatus.find_by(list: list, status: status)

        expect(list_status).to_not be_nil
        expect(notify?(follower, 'list_status', list_status.id)).to be true
      end
    end
  end
end
