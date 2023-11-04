# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnEmojiReactService, type: :service do
  subject do
    described_class.new.call(sender, status, emoji_reaction)
    EmojiReaction.where(status: status, account: sender)
  end

  let!(:emoji_reaction) { nil }
  let(:sender) { Fabricate(:user).account }
  let(:author) { Fabricate(:user).account }
  let(:status) { Fabricate(:status, account: author) }

  context 'when a simple case' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    it 'unreact with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'when no emoji reactions' do
    it 'unreact with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'with custom emoji of local' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: 'ohagi', custom_emoji: custom_emoji) }
    let(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi') }

    it 'react with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'with custom emoji of remote' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: 'ohagi', custom_emoji: custom_emoji) }
    let(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji/ohagi') }

    it 'react with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'when other account already set' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'unreact with emoji' do
      expect(subject.count).to eq 0
      expect(EmojiReaction.where(status: status).count).to eq 1
    end
  end

  context 'when this account already set multiple emojis' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before do
      Fabricate(:emoji_reaction, account: sender, status: status, name: '😂')
      Fabricate(:emoji_reaction, account: sender, status: status, name: '🚗')
    end

    it 'unreact with emoji' do
      expect(subject.count).to eq 2
      expect(subject.pluck(:name)).to contain_exactly('😂', '🚗')
    end
  end

  context 'with remove all emojis' do
    before do
      Fabricate(:emoji_reaction, account: sender, status: status, name: '😀')
      Fabricate(:emoji_reaction, account: sender, status: status, name: '😂')
      Fabricate(:emoji_reaction, account: sender, status: status, name: '🚗')
    end

    it 'react with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'when remote status' do
    let(:author) { Fabricate(:account, domain: 'author.foo.bar', uri: 'https://author.foo.bar/actor', inbox_url: 'https://author.foo.bar/inbox', protocol: 'activitypub') }
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before do
      stub_request(:post, 'https://author.foo.bar/inbox')
    end

    it 'react with emoji' do
      expect(subject.count).to eq 0
      expect(a_request(:post, 'https://author.foo.bar/inbox').with(body: hash_including({
        type: 'Undo',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end

  context 'when sender has remote followers' do
    let!(:bob) { Fabricate(:account, domain: 'foo.bar', uri: 'https://foo.bar/actor', inbox_url: 'https://foo.bar/inbox', protocol: 'activitypub') }
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before do
      bob.follow!(sender)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji' do
      expect(subject.count).to eq 0
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Undo',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end

  context 'when has relay server' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before do
      Fabricate(:relay, inbox_url: 'https://foo.bar/inbox', state: :accepted)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji' do
      expect(subject.count).to eq 0
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Undo',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end

  context 'when has friend server' do
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: sender, status: status, name: '😀') }

    before do
      Fabricate(:friend_domain, inbox_url: 'https://foo.bar/inbox', active_state: :accepted, pseudo_relay: true)
      stub_request(:post, 'https://foo.bar/inbox')
    end

    it 'react with emoji' do
      expect(subject.count).to eq 0
      expect(a_request(:post, 'https://foo.bar/inbox').with(body: hash_including({
        type: 'Undo',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        content: '😀',
      }))).to have_been_made.once
    end
  end
end
