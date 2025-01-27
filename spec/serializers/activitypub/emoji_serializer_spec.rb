# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::EmojiSerializer do
  describe '.serializer_for' do
    subject { serialized_record_json(model, described_class, adapter: ActivityPub::Adapter) }

    let(:model) { Fabricate(:custom_emoji) }

    context 'without license' do
      it 'does not have information' do
        expect(subject).to_not include({
          '_misskey_license' => { 'freeText' => 'Ohagi' },
        })
        expect(subject).to_not include({
          'license' => 'Ohagi',
        })
      end
    end

    context 'with license' do
      let(:model) { Fabricate(:custom_emoji, license: 'Ohagi') }

      it 'has information' do
        expect(subject).to include({
          'license' => 'Ohagi',
          '_misskey_license' => { 'freeText' => 'Ohagi' },
        })
      end
    end
  end
end
