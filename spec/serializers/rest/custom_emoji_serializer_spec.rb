# frozen_string_literal: true

require 'rails_helper'

describe REST::CustomEmojiSerializer do
  let(:serialization) { serialized_record_json(record, described_class) }
  let(:record) do
    Fabricate(:custom_emoji, shortcode: 'ohagi', aliases: aliases)
  end
  let(:aliases) { [] }

  context 'when empty aliases' do
    it 'returns normalized aliases' do
      expect(serialization['aliases']).to eq []
    end
  end

  context 'when null aliases' do
    let(:aliases) { nil }

    it 'returns normalized aliases' do
      expect(serialization['aliases']).to eq []
    end
  end

  context 'when aliases contains null' do
    let(:aliases) { [nil] }

    it 'returns normalized aliases' do
      expect(serialization['aliases']).to eq []
    end
  end

  context 'when aliases contains normal text' do
    let(:aliases) { ['neko'] }

    it 'returns normalized aliases' do
      expect(serialization['aliases']).to eq ['neko']
    end
  end
end
