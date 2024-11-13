# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateStatusExpirationService do
  subject { described_class.new.call(status) }

  let(:status) { Fabricate(:status, text: text) }

  before { travel_to '2023-01-01T00:00:00Z' }

  shared_examples 'set expire date' do |offset|
    it 'set expire date' do
      subject
      expect(ScheduledExpirationStatus.where(status: status).count).to eq 1
      expect(ScheduledExpirationStatus.exists?(scheduled_at: Time.now.utc + offset, status: status)).to be true
    end
  end

  shared_examples 'did not set expire date' do
    it 'did not set expire date' do
      subject
      expect(ScheduledExpirationStatus.exists?(status: status)).to be false
    end
  end

  context 'when 30 minutes' do
    let(:text) { 'ohagi #exp30m' }

    it_behaves_like 'set expire date', 30.minutes
  end

  context 'when 1 hour' do
    let(:text) { 'ohagi #exp1h' }

    it_behaves_like 'set expire date', 1.hour
  end

  context 'with multiple tags' do
    let(:text) { 'ohagi #exp3h #exp1d' }

    it_behaves_like 'set expire date', 3.hours
  end

  context 'when too long hours' do
    let(:text) { 'ohagi #exp9999999999h' }

    it_behaves_like 'did not set expire date'
  end

  context 'without tags' do
    let(:text) { 'ohagi is ohagi' }

    it_behaves_like 'did not set expire date'
  end

  context 'when update status text' do
    before do
      Fabricate(:scheduled_expiration_status, account: status.account, status: status)
    end

    context 'with new date' do
      let(:text) { 'ohagi #exp1h' }

      it_behaves_like 'set expire date', 1.hour
    end

    context 'without new date' do
      let(:text) { 'ohagi' }

      it_behaves_like 'did not set expire date'
    end
  end
end
