# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmojiReactService, type: :service do
  subject do
    described_class.new.call(sender, status, name)
    EmojiReaction.where(status: status, account: sender)
  end

  let(:name) { '😀' }
  let(:sender) { Fabricate(:user).account }
  let(:author) { Fabricate(:user).account }
  let(:status) { Fabricate(:status, account: author) }

  it 'with a simple case' do
    expect(subject.count).to eq 1
    expect(subject.first.name).to eq '😀'
    expect(subject.first.custom_emoji_id).to be_nil
  end

  context 'when multiple reactions by same account' do
    let(:name) { '😂' }

    before { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 2
      expect(subject.pluck(:name)).to contain_exactly('😀', '😂')
    end
  end

  context 'when already reacted by other account' do
    let(:name) { '😂' }

    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.pluck(:name)).to contain_exactly('😂')
      expect(EmojiReaction.where(status: status).count).to eq 2
    end
  end

  context 'when already reacted same emoji by other account', :tag do
    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq '😀'
      expect(EmojiReaction.where(status: status).count).to eq 2
    end
  end

  context 'when user is silenced' do
    before do
      sender.silence!
    end

    it 'emoji reaction is not allowed' do
      expect { subject }.to raise_error Mastodon::ValidationError
    end
  end

  context 'when user is silenced but following target' do
    before do
      author.follow!(sender)
      sender.silence!
    end

    it 'emoji reaction is allowed' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq '😀'
      expect(subject.first.custom_emoji_id).to be_nil
    end
  end

  context 'when over limit' do
    let(:name) { '🚗' }

    before do
      Fabricate(:emoji_reaction, status: status, account: sender, name: '😀')
      Fabricate(:emoji_reaction, status: status, account: sender, name: '😎')
      Fabricate(:emoji_reaction, status: status, account: sender, name: '🐟')
    end

    it 'react with emoji' do
      expect { subject.count }.to raise_error Mastodon::ValidationError

      reactions = EmojiReaction.where(status: status, account: sender).pluck(:name)
      expect(reactions.size).to eq 3
      expect(reactions).to contain_exactly('😀', '😎', '🐟')
    end
  end

  context 'with custom emoji of local' do
    let(:name) { 'ohagi' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq 'ohagi'
      expect(subject.first.custom_emoji.id).to eq custom_emoji.id
    end
  end

  context 'with custom emoji but not existing' do
    let(:name) { 'ohagi' }

    it 'react with emoji' do
      expect { subject.count }.to raise_error ActiveRecord::RecordInvalid
      expect(EmojiReaction.exists?(status: status, account: sender, name: 'ohagi')).to be false
    end
  end

  context 'with ng rule' do
    let(:name) { 'ohagi' }

    context 'when rule hits' do
      before do
        Fabricate(:custom_emoji, shortcode: 'ohagi')
        Fabricate(:ng_rule, reaction_type: ['emoji_reaction'])
      end

      it 'react with emoji' do
        expect { subject }.to raise_error Mastodon::ValidationError
      end
    end

    context 'when rule does not hit' do
      before do
        Fabricate(:custom_emoji, shortcode: 'ohagi')
        Fabricate(:ng_rule, reaction_type: ['emoji_reaction'], emoji_reaction_name: 'aaa')
      end

      it 'react with emoji' do
        expect { subject }.to_not raise_error
        expect(subject.count).to eq 1
      end
    end
  end

  context 'with custom emoji of remote' do
    let(:name) { 'ohagi@foo.bar' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji/ohagi') }

    before { Fabricate(:emoji_reaction, status: status, name: 'ohagi', custom_emoji: custom_emoji) }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq 'ohagi'
      expect(subject.first.custom_emoji.id).to eq custom_emoji.id
    end
  end

  context 'with custom emoji of remote without existing one' do
    let(:name) { 'ohagi@foo.bar' }

    before { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji/ohagi') }

    it 'react with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'with custom emoji of remote but local has same name emoji' do
    let(:name) { 'ohagi@foo.bar' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji/ohagi') }

    before do
      Fabricate(:custom_emoji, shortcode: 'ohagi', domain: nil)
      Fabricate(:emoji_reaction, status: status, name: 'ohagi', custom_emoji: custom_emoji)
    end

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq 'ohagi'
      expect(subject.first.custom_emoji.id).to eq custom_emoji.id
      expect(subject.first.custom_emoji.domain).to eq 'foo.bar'
    end
  end

  context 'with name duplication of unicode emoji on same account' do
    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq '😀'
    end
  end

  context 'with name duplication of local cuetom emoji on same account' do
    let(:name) { 'ohagi' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi') }

    before { Fabricate(:emoji_reaction, account: sender, status: status, name: 'ohagi', custom_emoji: custom_emoji) }

    it 'react with emoji' do
      expect { subject.count }.to raise_error Mastodon::ValidationError
    end
  end

  context 'with name duplication of remote cuetom emoji on same account' do
    let(:name) { 'ohagi@foo.bar' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji/ohagi') }

    before { Fabricate(:emoji_reaction, account: sender, status: status, name: 'ohagi', custom_emoji: custom_emoji) }

    it 'react with emoji' do
      expect { subject.count }.to raise_error Mastodon::ValidationError
    end
  end

  context 'when remote status' do
    let(:author) { Fabricate(:account, domain: 'author.foo.bar', uri: 'https://author.foo.bar/actor', inbox_url: 'https://author.foo.bar/inbox', protocol: 'activitypub') }

    before do
      stub_request(:post, 'https://author.foo.bar/inbox')
    end

    it 'react with emoji', :sidekiq_inline do
      expect(subject.count).to eq 1
      expect(a_request(:post, 'https://author.foo.bar/inbox').with(body: hash_including({
        type: 'Like',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end

    context 'when has followers' do
      let!(:bob) { Fabricate(:account, domain: 'foo.bar', uri: 'https://foo.bar/actor', inbox_url: 'https://foo.bar/inbox', protocol: 'activitypub') }

      before do
        bob.follow!(sender)
        stub_request(:post, 'https://foo.bar/inbox')
      end

      it 'react with emoji', :sidekiq_inline do
        expect(subject.count).to eq 1
        expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
          type: 'Like',
          actor: ActivityPub::TagManager.instance.uri_for(sender),
          content: '😀',
        }))).to have_been_made.once
      end
    end
  end

  context 'when sender has remote followers' do
    let!(:bob) { Fabricate(:account, domain: 'foo.bar', uri: 'https://foo.bar/actor', inbox_url: 'https://foo.bar/inbox', protocol: 'activitypub') }

    before do
      bob.follow!(sender)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji', :sidekiq_inline do
      expect(subject.count).to eq 1
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Like',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end

  context 'when has relay server' do
    before do
      Fabricate(:relay, inbox_url: 'https://foo.bar/inbox', state: :accepted)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji', :sidekiq_inline do
      expect(subject.count).to eq 1
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Like',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end

  context 'when has friend server' do
    before do
      Fabricate(:friend_domain, inbox_url: 'https://foo.bar/inbox', active_state: :accepted, pseudo_relay: true)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji', :sidekiq_inline do
      expect(subject.count).to eq 1
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Like',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end
end
