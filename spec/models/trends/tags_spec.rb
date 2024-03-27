# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trends::Tags do
  subject { described_class.new(threshold: 5, review_threshold: 10) }

  let!(:at_time) { DateTime.new(2021, 11, 14, 10, 15, 0) }

  describe '#add' do
    let(:tag) { Fabricate(:tag) }

    before do
      subject.add(tag, 1, at_time)
    end

    it 'records history' do
      expect(tag.history.get(at_time).accounts).to eq 1
    end

    it 'records use' do
      expect(subject.send(:recently_used_ids, at_time)).to eq [tag.id]
    end
  end

  describe '#register' do
    let(:tag) { Fabricate(:tag, usable: true) }
    let(:account) { Fabricate(:account) }
    let(:status) { Fabricate(:status, account: account, tags: [tag], created_at: at_time, updated_at: at_time) }

    it 'records history' do
      subject.register(status, at_time)
      expect(tag.history.get(at_time).accounts).to eq 1
      expect(tag.history.get(at_time).uses).to eq 1
      expect(subject.send(:recently_used_ids, at_time)).to eq [tag.id]
    end

    context 'when account is rejected appending trends' do
      let(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/actor') }

      before do
        Fabricate(:domain_block, domain: 'example.com', block_trends: true, severity: :noop)
      end

      it 'does not record history' do
        subject.register(status, at_time)
        expect(tag.history.get(at_time).accounts).to eq 0
        expect(tag.history.get(at_time).uses).to eq 0
      end
    end
  end

  describe '#query' do
    it 'returns a composable query scope' do
      expect(subject.query).to be_a Trends::Query
    end
  end

  describe '#refresh' do
    let!(:today) { at_time }
    let!(:yesterday) { today - 1.day }

    let!(:tag_cats) { Fabricate(:tag, name: 'Catstodon', trendable: true) }
    let!(:tag_dogs) { Fabricate(:tag, name: 'DogsOfMastodon', trendable: true) }
    let!(:tag_ocs) { Fabricate(:tag, name: 'OCs', trendable: true) }

    before do
      2.times  { |i| subject.add(tag_cats, i, yesterday) }
      13.times { |i| subject.add(tag_ocs, i, yesterday) }
      16.times { |i| subject.add(tag_cats, i, today) }
      4.times  { |i| subject.add(tag_dogs, i, today) }
    end

    context 'when tag trends are refreshed' do
      before do
        subject.refresh(yesterday + 12.hours)
        subject.refresh(at_time)
      end

      it 'calculates and re-calculates scores' do
        expect(subject.query.limit(10).to_a).to eq [tag_cats, tag_ocs]
      end

      it 'omits hashtags below threshold' do
        expect(subject.query.limit(10).to_a).to_not include(tag_dogs)
      end
    end

    it 'decays scores' do
      subject.refresh(yesterday + 12.hours)
      original_score = subject.score(tag_ocs.id)
      expect(original_score).to eq 144.0
      subject.refresh(yesterday + 12.hours + subject.options[:max_score_halflife])
      decayed_score = subject.score(tag_ocs.id)
      expect(decayed_score).to be <= original_score / 2
    end
  end
end
