# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CustomEmoji do
  describe '#search' do
    subject { described_class.search(search_term) }

    let(:custom_emoji) { Fabricate(:custom_emoji, shortcode: shortcode) }

    context 'when shortcode is exact' do
      let(:shortcode) { 'blobpats' }
      let(:search_term) { 'blobpats' }

      it 'finds emoji' do
        expect(subject).to include(custom_emoji)
      end
    end

    context 'when shortcode is partial' do
      let(:shortcode) { 'blobpats' }
      let(:search_term) { 'blob' }

      it 'finds emoji' do
        expect(subject).to include(custom_emoji)
      end
    end
  end

  describe '#local?' do
    subject { custom_emoji.local? }

    let(:custom_emoji) { Fabricate(:custom_emoji, domain: domain) }

    context 'when domain is nil' do
      let(:domain) { nil }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'when domain is present' do
      let(:domain) { 'example.com' }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#copy!' do
    subject do
      custom_emoji.copy!
      described_class.where.not(id: custom_emoji.id).find_by(domain: nil, shortcode: custom_emoji.shortcode)
    end

    context 'when a simple case' do
      let(:custom_emoji) { Fabricate(:custom_emoji, license: 'Ohagi', aliases: %w(aaa bbb), domain: 'example.com', uri: 'https://example.com/emoji') }

      it 'makes a copy ot the emoji' do
        emoji = subject
        expect(emoji).to_not be_nil
        expect(emoji.license).to eq 'Ohagi'
        expect(emoji.aliases).to eq %w(aaa bbb)
      end
    end

    context 'when local has already same emoji' do
      let(:custom_emoji) { Fabricate(:custom_emoji, domain: nil) }

      it 'does not make a copy of the emoji' do
        expect(subject).to be_nil
      end
    end

    context 'when aliases is null' do
      let(:custom_emoji) { Fabricate(:custom_emoji, aliases: nil, domain: 'example.com', uri: 'https://example.com/emoji') }

      it 'makes a copy of the emoji but aliases property is normalized' do
        emoji = subject
        expect(emoji).to_not be_nil
        expect(emoji.aliases).to eq []
      end
    end

    context 'when aliases contains null' do
      let(:custom_emoji) { Fabricate(:custom_emoji, aliases: [nil], domain: 'example.com', uri: 'https://example.com/emoji') }

      it 'makes a copy of the emoji but aliases property is normalized' do
        emoji = subject
        expect(emoji).to_not be_nil
        expect(emoji.aliases).to eq []
      end
    end
  end

  describe '#object_type' do
    it 'returns :emoji' do
      custom_emoji = Fabricate(:custom_emoji)
      expect(custom_emoji.object_type).to be :emoji
    end
  end

  describe '.from_text' do
    subject { described_class.from_text(text, nil) }

    let!(:emojo) { Fabricate(:custom_emoji, shortcode: 'coolcat') }

    context 'with plain text' do
      let(:text) { 'Hello :coolcat:' }

      it 'returns records used via shortcodes in text' do
        expect(subject).to include(emojo)
      end
    end

    context 'with html' do
      let(:text) { '<p>Hello :coolcat:</p>' }

      it 'returns records used via shortcodes in text' do
        expect(subject).to include(emojo)
      end
    end
  end

  describe 'pre_validation' do
    let(:custom_emoji) { Fabricate(:custom_emoji, domain: 'wWw.MaStOdOn.CoM') }

    it 'downcases' do
      custom_emoji.valid?
      expect(custom_emoji.domain).to eq('www.mastodon.com')
    end
  end
end
