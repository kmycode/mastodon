# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Like do
  let(:sender)    { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/') }
  let(:recipient) { Fabricate(:account) }
  let(:status)    { Fabricate(:status, account: recipient) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Like',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: ActivityPub::TagManager.instance.uri_for(status),
    }.with_indifferent_access
  end

  describe '#perform' do
    subject { described_class.new(json, sender) }

    before do
      subject.perform
    end

    it 'creates a favourite from sender to status' do
      expect(sender.favourited?(status)).to be true
    end
  end

  describe '#perform when receive emoji reaction' do
    subject do
      described_class.new(json, sender).perform
      EmojiReaction.where(status: status)
    end

    before do
      stub_request(:get, 'http://example.com/emoji.png').to_return(body: attachment_fixture('emojo.png'))
    end

    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Like',
        actor: ActivityPub::TagManager.instance.uri_for(sender),
        object: ActivityPub::TagManager.instance.uri_for(status),
        content: content,
        tag: tag,
      }.with_indifferent_access
    end
    let(:content) { nil }
    let(:tag) { nil }

    context 'with unicode emoji' do
      let(:content) { '😀' }

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq '😀'
        expect(subject.first.account).to eq sender
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with custom emoji' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/aaa',
          type: 'Emoji',
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
          license: 'Everyone but Ohagi',
        }
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq 'tinking'
        expect(subject.first.account).to eq sender
        expect(subject.first.custom_emoji).to_not be_nil
        expect(subject.first.custom_emoji.shortcode).to eq 'tinking'
        expect(subject.first.custom_emoji.domain).to eq 'example.com'
        expect(sender.favourited?(status)).to be false
      end

      it 'custom emoji license is saved' do
        expect(subject.first.custom_emoji.license).to eq 'Everyone but Ohagi'
      end
    end

    context 'with custom emoji and custom domain' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/aaa',
          type: 'Emoji',
          domain: 'post.kmycode.net',
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
        }
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq 'tinking'
        expect(subject.first.account).to eq sender
        expect(subject.first.custom_emoji).to_not be_nil
        expect(subject.first.custom_emoji.shortcode).to eq 'tinking'
        expect(subject.first.custom_emoji.domain).to eq 'post.kmycode.net'
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with custom emoji but invalid id' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'aaa',
          type: 'Emoji',
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
        }
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq 'tinking'
        expect(subject.first.account).to eq sender
        expect(subject.first.custom_emoji).to_not be_nil
        expect(subject.first.custom_emoji.shortcode).to eq 'tinking'
        expect(subject.first.custom_emoji.domain).to eq 'example.com'
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with custom emoji but local domain' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'aaa',
          type: 'Emoji',
          domain: Rails.configuration.x.local_domain,
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
        }
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq 'tinking'
        expect(subject.first.account).to eq sender
        expect(subject.first.custom_emoji).to_not be_nil
        expect(subject.first.custom_emoji.shortcode).to eq 'tinking'
        expect(subject.first.custom_emoji.domain).to be_nil
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with unicode emoji and reject_media enabled' do
      let(:content) { '😀' }

      before do
        Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_media: true)
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq '😀'
        expect(subject.first.account).to eq sender
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with custom emoji and reject_media enabled' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/aaa',
          type: 'Emoji',
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
        }
      end

      before do
        Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_media: true)
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'when emoji reaction is disabled' do
      let(:content) { '😀' }

      before do
        Form::AdminSettings.new(enable_emoji_reaction: false).save
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
        expect(sender.favourited?(status)).to be true
      end
    end

    context 'when emoji reaction between other servers is disabled' do
      let(:recipient) { Fabricate(:account, domain: 'narrow.com', uri: 'https://narrow.com/') }
      let(:content) { '😀' }

      before do
        Form::AdminSettings.new(receive_other_servers_emoji_reaction: false).save
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'when emoji reaction between other servers is disabled but that status is local' do
      let(:content) { '😀' }

      before do
        Form::AdminSettings.new(receive_other_servers_emoji_reaction: false).save
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq '😀'
        expect(subject.first.account).to eq sender
        expect(sender.favourited?(status)).to be false
      end
    end
  end

  describe '#perform when domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_favourite: true)
      subject.perform
    end

    it 'does not create a favourite from sender to status' do
      expect(sender.favourited?(status)).to be false
    end
  end

  describe '#perform when normal domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:domain_block, domain: 'example.com', severity: :suspend)
      subject.perform
    end

    it 'does not create a favourite from sender to status' do
      expect(sender.favourited?(status)).to be false
    end
  end

  describe '#perform when account domain_block' do
    subject { described_class.new(json, sender) }

    before do
      Fabricate(:account_domain_block, account: recipient, domain: 'example.com')
      subject.perform
    end

    it 'does not create a favourite from sender to status', pending: 'considering spec' do
      expect(sender.favourited?(status)).to be false
    end
  end
end
