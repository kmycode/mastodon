# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SensitiveWord do
  describe '#sensitive?' do
    subject { described_class.sensitive?(text, spoiler_text, local: local) }

    let(:text) { 'This is a ohagi.' }
    let(:spoiler_text) { '' }
    let(:local) { true }

    context 'when a local post' do
      it 'local word hits' do
        Fabricate(:sensitive_word, keyword: 'ohagi', remote: false)
        expect(subject).to be true
      end

      it 'remote word hits' do
        Fabricate(:sensitive_word, keyword: 'ohagi', remote: true)
        expect(subject).to be true
      end
    end

    context 'when a remote post' do
      let(:local) { false }

      it 'local word does not hit' do
        Fabricate(:sensitive_word, keyword: 'ohagi', remote: false)
        expect(subject).to be false
      end

      it 'remote word hits' do
        Fabricate(:sensitive_word, keyword: 'ohagi', remote: true)
        expect(subject).to be true
      end
    end

    context 'when using regexp' do
      it 'regexp hits with enable' do
        Fabricate(:sensitive_word, keyword: 'oha[ghi]i', regexp: true)
        expect(subject).to be true
      end

      it 'regexp does not hit without enable' do
        Fabricate(:sensitive_word, keyword: 'oha[ghi]i', regexp: false)
        expect(subject).to be false
      end
    end

    context 'when spoiler text is set' do
      let(:spoiler_text) { 'amy' }

      it 'sensitive word in content is escaped' do
        Fabricate(:sensitive_word, keyword: 'ohagi', spoiler: false)
        expect(subject).to be false
      end

      it 'sensitive word in content is escaped even if spoiler is true' do
        Fabricate(:sensitive_word, keyword: 'ohagi', spoiler: true)
        expect(subject).to be false
      end

      it 'non-spoiler word does not hit' do
        Fabricate(:sensitive_word, keyword: 'amy', spoiler: false)
        expect(subject).to be false
      end

      it 'spoiler word hits' do
        Fabricate(:sensitive_word, keyword: 'amy', spoiler: true)
        expect(subject).to be true
      end
    end
  end
end
