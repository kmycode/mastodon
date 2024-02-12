# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vacuum::StatusesVacuum do
  subject { described_class.new(retention_period) }

  let(:retention_period) { 7.days }

  let(:local_account) { Fabricate(:account) }
  let(:remote_account) { Fabricate(:account, domain: 'example.com') }

  describe '#perform' do
    let!(:remote_status_old) { Fabricate(:status, account: remote_account, created_at: (retention_period + 2.days).ago) }
    let!(:remote_status_recent) { Fabricate(:status, account: remote_account, created_at: (retention_period - 2.days).ago) }
    let!(:local_status_old) { Fabricate(:status, created_at: (retention_period + 2.days).ago) }
    let!(:local_status_recent) { Fabricate(:status, created_at: (retention_period - 2.days).ago) }

    before do
      subject.perform
    end

    it 'deletes remote statuses past the retention period' do
      expect { remote_status_old.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does not delete local statuses past the retention period' do
      expect { local_status_old.reload }.to_not raise_error
    end

    it 'does not delete remote statuses within the retention period' do
      expect { remote_status_recent.reload }.to_not raise_error
    end

    it 'does not delete local statuses within the retention period' do
      expect { local_status_recent.reload }.to_not raise_error
    end
  end

  describe '#perform with reaction' do
    let!(:remote_status_old) { Fabricate(:status, account: remote_account, created_at: (retention_period + 2.days).ago) }
    let!(:remote_status_old_faved_byl) { Fabricate(:status, account: remote_account, created_at: (retention_period + 2.days).ago) }
    let!(:remote_status_old_faved_byr) { Fabricate(:status, account: remote_account, created_at: (retention_period + 2.days).ago) }
    let!(:remote_status_old_bmed_byl) { Fabricate(:status, account: remote_account, created_at: (retention_period + 2.days).ago) }

    let(:delete_content_cache_without_reaction) { true }

    before do
      Setting.delete_content_cache_without_reaction = delete_content_cache_without_reaction
      Fabricate(:favourite, account: local_account, status: remote_status_old_faved_byl)
      Fabricate(:favourite, account: remote_account, status: remote_status_old_faved_byr, uri: 'https://example.com/fav')
      Fabricate(:bookmark, account: local_account, status: remote_status_old_bmed_byl)
      subject.perform
    end

    it 'deletes remote statuses past the retention period' do
      expect { remote_status_old.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'deletes remote statuses favourited by remote user' do
      expect { remote_status_old_faved_byr.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does not delete remote statuses favourited by local user' do
      expect { remote_status_old_faved_byl.reload }.to_not raise_error
    end

    it 'does not delete remote statuses bookmarked by local user' do
      expect { remote_status_old_bmed_byl.reload }.to_not raise_error
    end

    context 'when excepting is disabled' do
      let(:delete_content_cache_without_reaction) { false }

      it 'deletes remote statuses past the retention period' do
        expect { remote_status_old.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'deletes remote statuses favourited by remote user' do
        expect { remote_status_old_faved_byr.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'deletes remote statuses favourited by local user' do
        expect { remote_status_old_faved_byl.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'deletes remote statuses bookmarked by local user' do
        expect { remote_status_old_bmed_byl.reload }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end
end
