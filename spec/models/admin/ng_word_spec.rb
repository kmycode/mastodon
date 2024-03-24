# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::NgWord do
  describe '#reject?' do
    subject { described_class.reject?(text, stranger: stranger, uri: uri, target_type: :status) }

    let(:text) { 'This is a ohagi.' }
    let(:stranger) { false }
    let(:uri) { nil }

    context 'when general post' do
      it 'ng word hits' do
        Fabricate(:ng_word, keyword: 'ohagi', stranger: false)
        expect(subject).to be true
      end

      it 'else ng word does not hit' do
        Fabricate(:ng_word, keyword: 'angry', stranger: false)
        expect(subject).to be false
      end

      it 'stranger word does not hit' do
        Fabricate(:ng_word, keyword: 'ohagi', stranger: true)
        expect(subject).to be false
      end
    end

    context 'when mention to stranger' do
      let(:stranger) { true }

      it 'ng word hits' do
        Fabricate(:ng_word, keyword: 'ohagi', stranger: true)
        expect(subject).to be true
      end

      it 'else ng word does not hit' do
        Fabricate(:ng_word, keyword: 'angry', stranger: true)
        expect(subject).to be false
      end

      it 'general word hits' do
        Fabricate(:ng_word, keyword: 'ohagi', stranger: false)
        expect(subject).to be true
      end
    end

    context 'when remote post' do
      let(:uri) { 'https://example.com/note' }

      it 'ng word hits' do
        Fabricate(:ng_word, keyword: 'ohagi', stranger: false)
        expect(subject).to be true
        expect(NgwordHistory.find_by(uri: uri)).to_not be_nil
      end

      it 'else ng word does not hit' do
        Fabricate(:ng_word, keyword: 'angry', stranger: false)
        expect(subject).to be false
        expect(NgwordHistory.find_by(uri: uri)).to be_nil
      end
    end

    context 'when using regexp' do
      it 'regexp hits with enable' do
        Fabricate(:ng_word, keyword: 'oha[ghi]i', regexp: true, stranger: false)
        expect(subject).to be true
      end

      it 'regexp does not hit without enable' do
        Fabricate(:ng_word, keyword: 'oha[ghi]i', regexp: false, stranger: false)
        expect(subject).to be false
      end
    end
  end
end
