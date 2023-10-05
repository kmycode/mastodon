# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FanOutOnWriteService, type: :service do
  subject { described_class.new }

  let(:last_active_at) { Time.now.utc }
  let(:searchability) { 'public' }
  let(:dissubscribable) { false }
  let(:status) { Fabricate(:status, account: alice, visibility: visibility, searchability: searchability, text: 'Hello @bob #hoge') }

  let!(:alice) { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { dissubscribable: dissubscribable }).account }
  let!(:bob)   { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { username: 'bob' }).account }
  let!(:tom)   { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:ohagi) { Fabricate(:user, current_sign_in_at: last_active_at).account }

  let!(:list)          { nil }
  let!(:empty_list)    { nil }
  let!(:antenna)       { nil }
  let!(:empty_antenna) { nil }

  before do
    bob.follow!(alice)
    tom.follow!(alice)
    ohagi.follow!(bob)

    ProcessMentionsService.new.call(status)
    ProcessHashtagsService.new.call(status)

    allow(redis).to receive(:publish)

    subject.call(status)
  end

  def home_feed_of(account)
    HomeFeed.new(account).get(10).map(&:id)
  end

  def list_feed_of(list)
    ListFeed.new(list).get(10).map(&:id)
  end

  def antenna_feed_of(antenna)
    AntennaFeed.new(antenna).get(10).map(&:id)
  end

  def list_with_account(owner, target_account)
    list = Fabricate(:list, account: owner)
    Fabricate(:list_account, list: list, account: target_account)
    list
  end

  def antenna_with_account(owner, target_account)
    antenna = Fabricate(:antenna, account: owner, any_accounts: false)
    Fabricate(:antenna_account, antenna: antenna, account: target_account)
    antenna
  end

  def antenna_with_options(owner, **options)
    Fabricate(:antenna, account: owner, **options)
  end

  context 'when status is public' do
    let(:visibility) { 'public' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower' do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is broadcast to the hashtag stream' do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge:local', anything)
    end

    it 'is broadcast to the public stream' do
      expect(redis).to have_received(:publish).with('timeline:public', anything)
      expect(redis).to have_received(:publish).with('timeline:public:local', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { Fabricate(:list, account: tom) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, bob) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is not added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to_not include status.id
        end
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:antenna) { antenna_with_options(bob, ltl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to include status.id
        end
      end
    end
  end

  context 'when status is limited' do
    let(:visibility) { 'limited' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of the mentioned follower' do
      expect(home_feed_of(bob)).to include status.id
    end

    it 'is not added to the home feed of the other follower' do
      expect(home_feed_of(tom)).to_not include status.id
    end

    it 'is not broadcast publicly' do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(tom, alice) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, alice) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom, stl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'when status is private' do
    let(:visibility) { 'private' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower' do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is not broadcast publicly' do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(ohagi, stl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'when status is public_unlisted' do
    let(:visibility) { 'public_unlisted' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower' do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is broadcast publicly' do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to have_received(:publish).with('timeline:public:local', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, bob) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is not added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to_not include status.id
        end
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:antenna) { antenna_with_options(bob, ltl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when dissubscribable is true' do
        let(:dissubscribable) { true }

        it 'is added to the antenna feed' do
          expect(antenna_feed_of(antenna)).to include status.id
        end
      end
    end
  end

  context 'when status is unlisted' do
    let(:visibility) { 'unlisted' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower' do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is not broadcast publicly' do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with searchability public_unlisted' do
      let(:searchability) { 'public_unlisted' }

      it 'is not broadcast to the hashtag stream' do
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end
    end

    context 'with searchability private' do
      let(:searchability) { 'private' }

      it 'is not broadcast to the hashtag stream' do
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(ohagi, stl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower' do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with non-public searchability' do
      let(:searchability) { 'direct' }

      it 'hashtag-timeline is not detected' do
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:public', anything)
      end
    end
  end

  context 'when status is direct' do
    let(:visibility) { 'direct' }

    it 'is added to the home feed of its author' do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of the mentioned follower' do
      expect(home_feed_of(bob)).to include status.id
    end

    it 'is not added to the home feed of the other follower' do
      expect(home_feed_of(tom)).to_not include status.id
    end

    it 'is not broadcast publicly' do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower' do
        expect(list_feed_of(list)).to_not include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower' do
        expect(antenna_feed_of(antenna)).to_not include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end
end
