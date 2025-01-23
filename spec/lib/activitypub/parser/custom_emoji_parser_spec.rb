# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Parser::CustomEmojiParser do
  subject { described_class.new(json) }

  context 'with fedibird license' do
    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: ['https://example.com/#foo'].join,
        name: 'ohagi',
        license: 'Ohagi is ohagi',
      }.with_indifferent_access
    end

    it 'load license' do
      expect(subject.license).to eq 'Ohagi is ohagi'
    end
  end

  context 'with misskey license' do
    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: ['https://example.com/#foo'].join,
        name: 'ohagi',
        _misskey_license: {
          freeText: 'Ohagi is ohagi',
        },
      }.with_indifferent_access
    end

    it 'load license' do
      expect(subject.license).to eq 'Ohagi is ohagi'
    end
  end

  context 'without license' do
    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: ['https://example.com/#foo'].join,
        name: 'ohagi',
      }.with_indifferent_access
    end

    it 'do not load license' do
      expect(subject.license).to be_nil
    end
  end
end
