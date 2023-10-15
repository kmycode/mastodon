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

  context 'with name duplication on same account' do
    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq '😀'
    end
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
    end
  end

  context 'when already reacted same emoji by other account', :tag do
    before { Fabricate(:emoji_reaction, status: status, name: '😀') }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq '😀'
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

  context 'with custom emoji of remote' do
    let(:name) { 'ohagi@foo.bar' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar') }

    before { Fabricate(:emoji_reaction, status: status, name: 'ohagi', custom_emoji: custom_emoji) }

    it 'react with emoji' do
      expect(subject.count).to eq 1
      expect(subject.first.name).to eq 'ohagi'
      expect(subject.first.custom_emoji.id).to eq custom_emoji.id
    end
  end

  context 'with custom emoji of remote without existing one' do
    let(:name) { 'ohagi@foo.bar' }

    before { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar') }

    it 'react with emoji' do
      expect(subject.count).to eq 0
    end
  end

  context 'with custom emoji of remote but local has same name emoji' do
    let(:name) { 'ohagi@foo.bar' }
    let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar') }

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
end
