# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FanOutOnWriteService do
  subject { described_class.new }

  let(:ltl_enabled) { true }

  let(:last_active_at) { Time.now.utc }
  let(:visibility) { 'public' }
  let(:searchability) { 'public' }
  let(:subscription_policy) { :allow }
  let(:status) { Fabricate(:status, account: alice, visibility: visibility, searchability: searchability, text: 'Hello @bob @eve #hoge') }

  let!(:alice) { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { master_settings: { subscription_policy: subscription_policy } }).account }
  let!(:bob)   { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { username: 'bob' }).account }
  let!(:tom)   { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:ohagi) { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:tagf)  { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:eve)   { Fabricate(:user, current_sign_in_at: last_active_at, account_attributes: { username: 'eve' }).account }

  let!(:list)          { nil }
  let!(:empty_list)    { nil }
  let!(:antenna)       { nil }
  let!(:empty_antenna) { nil }

  let(:custom_before) { false }

  before do
    bob.follow!(alice)
    tom.follow!(alice)
    ohagi.follow!(bob)

    Form::AdminSettings.new(enable_local_timeline: '0').save unless ltl_enabled

    ProcessMentionsService.new.call(status)
    ProcessHashtagsService.new.call(status)

    Fabricate(:media_attachment, status: status, account: alice)

    allow(redis).to receive(:publish)

    tag = status.tags.first
    Fabricate(:tag_follow, account: tagf, tag: tag) if tag.present?

    subject.call(status) unless custom_before
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

  def antenna_with_tag(owner, target_tag, **options)
    antenna = Fabricate(:antenna, account: owner, any_tags: false, **options)
    tag = Tag.find_or_create_by_names([target_tag])[0]
    Fabricate(:antenna_tag, antenna: antenna, tag: tag)
    antenna
  end

  def antenna_with_options(owner, **options)
    Fabricate(:antenna, account: owner, **options)
  end

  context 'when status is public' do
    let(:visibility) { 'public' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of the mentioned follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
    end

    it 'is added to the home feed of a follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to include status.id
    end

    it 'is broadcast to the hashtag stream', :inline_jobs do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge:local', anything)
    end

    it 'is broadcast to the public stream', :inline_jobs do
      expect(redis).to have_received(:publish).with('timeline:public', anything)
      expect(redis).to have_received(:publish).with('timeline:public:local', anything)
      expect(redis).to have_received(:publish).with('timeline:public:media', anything)
    end

    context 'when local timeline is disabled', :inline_jobs do
      let(:ltl_enabled) { false }

      it 'is broadcast to the hashtag stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end

      it 'is broadcast to the public stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:public', anything)
        expect(redis).to_not have_received(:publish).with('timeline:public:local', anything)
      end
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { Fabricate(:list, account: tom) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, bob) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'with subscription policy' do
        context 'when subscription is blocked' do
          let(:subscription_policy) { :block }
          let(:alice) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/alice', subscription_policy: subscription_policy) }

          it 'is not added to the antenna feed', :inline_jobs do
            expect(antenna_feed_of(antenna)).to_not include status.id
          end
        end

        context 'when local user subscription policy is disabled' do
          let(:subscription_policy) { :block }

          it 'is added to the antenna feed', :inline_jobs do
            expect(antenna_feed_of(antenna)).to include status.id
          end
        end

        context 'when subscription is allowed followers only' do
          let(:subscription_policy) { :followers_only }
          let!(:antenna) { antenna_with_account(ohagi, alice) }
          let(:alice) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/alice', subscription_policy: subscription_policy) }

          it 'is not added to the antenna feed', :inline_jobs do
            expect(antenna_feed_of(antenna)).to_not include status.id
          end

          context 'with following' do
            let!(:antenna) { antenna_with_account(bob, alice) }

            it 'is added to the antenna feed', :inline_jobs do
              expect(antenna_feed_of(antenna)).to include status.id
            end
          end
        end
      end

      context 'when dtl post' do
        let!(:antenna) { antenna_with_tag(bob, 'hoge') }

        around do |example|
          ClimateControl.modify DTL_ENABLED: 'true', DTL_TAG: 'hoge' do
            example.run
          end
        end

        context 'with listening tag' do
          it 'is added to the antenna feed', :inline_jobs do
            expect(antenna_feed_of(antenna)).to include status.id
          end
        end
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower' do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:antenna) { antenna_with_options(bob, ltl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'when handling status updates' do
      before do
        subject.call(status)

        status.snapshot!(at_time: status.created_at, rate_limit: false)
        status.update!(text: 'Hello @bob @eve #hoge (edited)')
        status.snapshot!(account_id: status.account_id)

        redis.set("subscribed:timeline:#{eve.id}:notifications", '1')
      end

      it 'pushes the update to mentioned users through the notifications streaming channel' do
        subject.call(status, update: true)
        expect(PushUpdateWorker).to have_enqueued_sidekiq_job(anything, status.id, "timeline:#{eve.id}:notifications", { 'update' => true })
      end
    end
  end

  context 'when status is limited' do
    let(:visibility) { 'limited' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of the mentioned follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
    end

    it 'is not added to the home feed of the other follower', :inline_jobs do
      expect(home_feed_of(tom)).to_not include status.id
    end

    it 'is not added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to_not include status.id
    end

    it 'is not broadcast publicly', :inline_jobs do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(tom, alice) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, alice) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom, stl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'when status is private' do
    let(:visibility) { 'private' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is not added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to_not include status.id
    end

    it 'is not broadcast publicly', :inline_jobs do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    it 'is added to the home feed of the mentioned follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(ohagi, stl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end
  end

  context 'when status is public_unlisted' do
    let(:visibility) { 'public_unlisted' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to include status.id
    end

    it 'is broadcast publicly', :inline_jobs do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to have_received(:publish).with('timeline:public:local', anything)
      expect(redis).to have_received(:publish).with('timeline:public', anything)
    end

    context 'when local timeline is disabled' do
      let(:ltl_enabled) { false }

      it 'is broadcast to the hashtag stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end

      it 'is broadcast to the public stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:public', anything)
        expect(redis).to_not have_received(:publish).with('timeline:public:local', anything)
      end
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(tom, bob) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:antenna) { antenna_with_options(bob, ltl: true) }
      let!(:empty_antenna) { antenna_with_options(tom) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end
  end

  context 'when status is unlisted' do
    let(:visibility) { 'unlisted' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of a follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end

    it 'is added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to include status.id
    end

    it 'is not broadcast publicly', :inline_jobs do
      expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with searchability public_unlisted' do
      let(:searchability) { 'public_unlisted' }

      it 'is broadcast to the hashtag stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end

      it 'is added to the tag follower', :inline_jobs do
        expect(home_feed_of(tagf)).to include status.id
      end
    end

    context 'with searchability private' do
      let(:searchability) { 'private' }

      it 'is not broadcast to the hashtag stream', :inline_jobs do
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end

      it 'is not added to the tag follower', :inline_jobs do
        expect(home_feed_of(tagf)).to_not include status.id
      end
    end

    context 'when local timeline is disabled' do
      let(:ltl_enabled) { false }

      it 'is broadcast to the hashtag stream', :inline_jobs do
        expect(redis).to have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge:local', anything)
      end
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'with STL antenna' do
      let!(:antenna) { antenna_with_options(bob, stl: true) }
      let!(:empty_antenna) { antenna_with_options(ohagi, stl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(antenna)).to_not include status.id
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'with LTL antenna' do
      let!(:empty_antenna) { antenna_with_options(bob, ltl: true) }

      it 'is added to the antenna feed of antenna follower', :inline_jobs do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end

      context 'when local timeline is disabled' do
        let(:ltl_enabled) { false }

        it 'is not added to the antenna feed of antenna follower', :inline_jobs do
          expect(antenna_feed_of(empty_antenna)).to_not include status.id
        end
      end
    end

    context 'with non-public searchability' do
      let(:searchability) { 'direct' }

      it 'hashtag-timeline is not detected', :inline_jobs do
        expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
        expect(redis).to_not have_received(:publish).with('timeline:public', anything)
      end
    end
  end

  context 'when status is direct' do
    let(:visibility) { 'direct' }

    it 'is added to the home feed of its author', :inline_jobs do
      expect(home_feed_of(alice)).to include status.id
    end

    it 'is added to the home feed of the mentioned follower', :inline_jobs do
      expect(home_feed_of(bob)).to include status.id
    end

    it 'is not added to the home feed of the other follower', :inline_jobs do
      expect(home_feed_of(tom)).to_not include status.id
    end

    it 'is not added to the tag follower', :inline_jobs do
      expect(home_feed_of(tagf)).to_not include status.id
    end

    it 'is not broadcast publicly', :inline_jobs do
      expect(redis).to_not have_received(:publish).with('timeline:hashtag:hoge', anything)
      expect(redis).to_not have_received(:publish).with('timeline:public', anything)
    end

    context 'with list' do
      let!(:list) { list_with_account(bob, alice) }
      let!(:empty_list) { list_with_account(ohagi, bob) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(list_feed_of(list)).to_not include status.id
        expect(list_feed_of(empty_list)).to_not include status.id
      end
    end

    context 'with antenna' do
      let!(:antenna) { antenna_with_account(bob, alice) }
      let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

      it 'is added to the list feed of list follower', :inline_jobs do
        expect(antenna_feed_of(antenna)).to_not include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'when status has a conversation' do
    let(:conversation) { Fabricate(:conversation) }
    let(:status) { Fabricate(:status, account: alice, visibility: visibility, thread: parent_status, conversation: conversation) }
    let(:parent_status) { Fabricate(:status, account: bob, visibility: visibility, conversation: conversation) }
    let(:zilu) { Fabricate(:user, current_sign_in_at: last_active_at).account }
    let(:custom_before) { true }

    before do
      zilu.follow!(alice)
      zilu.follow!(bob)
      Fabricate(:status, account: tom, visibility: visibility, conversation: conversation)
      Fabricate(:status, account: ohagi, visibility: visibility, conversation: conversation)
      status.mentions << Fabricate(:mention, account: bob, silent: true)
      status.mentions << Fabricate(:mention, account: ohagi, silent: true)
      status.mentions << Fabricate(:mention, account: zilu, silent: true)
      status.mentions << Fabricate(:mention, account: tom, silent: false)
      status.save
      subject.call(status)
    end

    context 'when public visibility' do
      it 'does not create notification', :inline_jobs do
        notification = Notification.find_by(account: bob, type: 'mention')

        expect(notification).to be_nil
      end

      it 'creates notification for active mention', :inline_jobs do
        notification = Notification.find_by(account: tom, type: 'mention')

        expect(notification).to_not be_nil
        expect(notification.mention.status_id).to eq status.id
      end

      it 'inserts home feed for reply', :inline_jobs do
        expect(home_feed_of(bob)).to include status.id
      end

      it 'inserts home feed for non-replied but mentioned and following replied account', :inline_jobs do
        expect(home_feed_of(zilu)).to include status.id
      end

      it 'does not insert home feed for non-replied, non-following replied account but mentioned', :inline_jobs do
        expect(home_feed_of(tom)).to_not include status.id
      end
    end

    context 'when limited visibility' do
      let(:visibility) { :limited }

      it 'creates notification', :inline_jobs do
        notification = Notification.find_by(account: bob, type: 'mention')

        expect(notification).to_not be_nil
        expect(notification.mention.status_id).to eq status.id
      end

      it 'creates notification for other conversation account', :inline_jobs do
        notification = Notification.find_by(account: ohagi, type: 'mention')

        expect(notification).to_not be_nil
        expect(notification.mention.status_id).to eq status.id
      end

      it 'inserts home feed for reply', :inline_jobs do
        expect(home_feed_of(bob)).to include status.id
      end

      it 'inserts home feed for non-replied but mentioned and following replied account', :inline_jobs do
        expect(home_feed_of(zilu)).to include status.id
      end

      it 'does not insert home feed for non-replied, non-following replied account but mentioned', :inline_jobs do
        expect(home_feed_of(tom)).to_not include status.id
      end
    end
  end

  context 'when updated status is already boosted or quoted' do
    let(:custom_before) { true }

    before do
      ReblogService.new.call(bob, status)
      PostStatusService.new.call(tom, text: "Hello QT #{ActivityPub::TagManager.instance.uri_for(status)}")

      subject.call(status, update: true)
    end

    it 'notified to boosted account', :inline_jobs do
      notification = Notification.find_by(account: bob, type: 'update')

      expect(notification).to_not be_nil
      expect(notification.activity_id).to eq status.id
    end

    it 'notified to quoted account', :inline_jobs do
      notification = Notification.find_by(account: tom, type: 'update')

      expect(notification).to_not be_nil
      expect(notification.activity_id).to eq status.id
    end

    it 'notified not to non-boosted account', :inline_jobs do
      notification = Notification.find_by(account: ohagi, type: 'update')

      expect(notification).to be_nil
    end
  end
end
