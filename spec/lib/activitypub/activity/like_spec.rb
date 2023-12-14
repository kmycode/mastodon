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
  let(:original_emoji) do
    {
      id: 'https://example.com/aaa',
      type: 'Emoji',
      icon: {
        url: 'http://example.com/emoji.png',
      },
      name: 'tinking',
      license: 'This is ohagi',
    }
  end
  let(:original_invalid_emoji) do
    {
      id: 'https://example.com/invalid',
      type: 'Emoji',
      icon: {
        url: 'http://example.com/emoji.png',
      },
      name: 'other',
      license: 'This is other ohagi',
    }
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
      stub_request(:get, 'http://foo.bar/emoji2.png').to_return(body: attachment_fixture('emojo.png'))
      stub_request(:get, 'https://example.com/aaa').to_return(status: 200, body: Oj.dump(original_emoji))
      stub_request(:get, 'https://example.com/invalid').to_return(status: 200, body: Oj.dump(original_invalid_emoji))
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

    context 'with custom emoji but that is existing on local server' do
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

      before do
        Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', image_remote_url: 'http://example.com/emoji.png', shortcode: 'tinking', license: 'Everyone but Ohagi')
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

    context 'with custom emoji from non-original server account' do
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
        sender.update(domain: 'ohagi.com')
        Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', shortcode: 'tinking')
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

    context 'with custom emoji and update license from non-original server account' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/aaa',
          type: 'Emoji',
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
          license: 'Old license',
        }
      end

      before do
        sender.update(domain: 'ohagi.com')
        Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', shortcode: 'tinking')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.custom_emoji.license).to eq 'This is ohagi'
        expect(sender.favourited?(status)).to be false
      end
    end

    context 'with custom emoji but icon url is not valid' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/aaa',
          type: 'Emoji',
          icon: {
            url: 'http://foo.bar/emoji.png',
          },
          name: 'tinking',
          license: 'Good for using darwin',
        }
      end

      before do
        sender.update(domain: 'ohagi.com')
        Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', shortcode: 'tinking', image_remote_url: 'http://example.com/emoji.png')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.custom_emoji.reload.license).to eq 'This is ohagi'
        expect(subject.first.custom_emoji.image_remote_url).to eq 'http://example.com/emoji.png'
      end
    end

    context 'with custom emoji but uri is not valid' do
      let(:content) { ':tinking:' }
      let(:tag) do
        {
          id: 'https://example.com/invalid',
          type: 'Emoji',
          icon: {
            url: 'http://foo.bar/emoji2.png',
          },
          name: 'tinking',
          license: 'Good for using darwin',
        }
      end

      before do
        sender.update(domain: 'ohagi.com')
        Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', shortcode: 'tinking', image_remote_url: 'http://example.com/emoji.png')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
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
          id: 'https://cb6e6126.ngrok.io/aaa',
          type: 'Emoji',
          domain: Rails.configuration.x.local_domain,
          icon: {
            url: 'http://example.com/emoji.png',
          },
          name: 'tinking',
          license: 'Ohagi but everyone',
        }
      end

      before do
        Fabricate(:custom_emoji, domain: nil, shortcode: 'tinking', license: 'Everyone but Ohagi')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
        expect(subject.first.name).to eq 'tinking'
        expect(subject.first.account).to eq sender
        expect(subject.first.custom_emoji).to_not be_nil
        expect(subject.first.custom_emoji.shortcode).to eq 'tinking'
        expect(subject.first.custom_emoji.domain).to be_nil
        expect(subject.first.custom_emoji.license).to eq 'Everyone but Ohagi'
        expect(sender.favourited?(status)).to be false
      end

      it 'not change license' do
        expect(subject.first.custom_emoji.reload.license).to eq 'Everyone but Ohagi'
        expect(subject.first.custom_emoji.reload.uri).to be_nil
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

    context 'when receiver is blocking sender' do
      let(:content) { '😀' }

      before do
        recipient.block!(sender)
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
      end
    end

    context 'when receiver is blocking emoji reactions' do
      let(:content) { '😀' }

      before do
        recipient.user.settings['emoji_reaction_policy'] = 'block'
        recipient.user.save!
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
      end
    end

    context 'when receiver is domain-blocking emoji reactions' do
      let(:content) { '😀' }

      before do
        recipient.domain_blocks.create!(domain: 'example.com')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 0
      end
    end

    context 'when receiver is not domain-blocking emoji reactions' do
      let(:content) { '😀' }

      before do
        recipient.domain_blocks.create!(domain: 'other-example.com')
      end

      it 'create emoji reaction' do
        expect(subject.count).to eq 1
      end
    end

    context 'when my server is silencing sender server' do
      let(:block_domain) { 'example.com' }
      let(:follow) { false }

      before do
        Fabricate(:domain_block, domain: block_domain, severity: :silence)
        recipient.follow!(sender) if follow
      end

      context 'with unicode emoji' do
        let(:content) { '😀' }

        it 'does not create emoji reaction' do
          expect(subject.count).to eq 0
        end

        context 'when following' do
          let(:follow) { true }

          it 'create emoji reaction' do
            expect(subject.count).to eq 1
            expect(subject.first.name).to eq '😀'
            expect(subject.first.account).to eq sender
            expect(sender.favourited?(status)).to be false
          end
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

        it 'does not create emoji reaction' do
          expect(subject.count).to eq 0
        end

        context 'when following' do
          let(:follow) { true }

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
      end

      context 'with custom emoji from non-original server account' do
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
          sender.update(domain: 'ohagi.com')
          Fabricate(:custom_emoji, domain: 'example.com', uri: 'https://example.com/aaa', shortcode: 'tinking')
        end

        it 'does not create emoji reaction' do
          expect(subject.count).to eq 0
        end

        context 'when following' do
          let(:follow) { true }

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
      end
    end
  end

  describe '#perform when rejecting favourite domain block' do
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
end
