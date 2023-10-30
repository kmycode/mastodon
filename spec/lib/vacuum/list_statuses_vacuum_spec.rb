# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vacuum::ListStatusesVacuum do
  subject { described_class.new }

  describe '#perform' do
    let!(:local_status_old) { Fabricate(:status, created_at: 2.days.ago) }
    let!(:local_status_recent) { Fabricate(:status, created_at: 5.hours.ago) }
    let!(:list_status_old) { Fabricate(:list_status, status: local_status_old, created_at: local_status_old.created_at) }
    let!(:list_status_recent) { Fabricate(:list_status, status: local_status_recent, created_at: local_status_recent.created_at) }

    before do
      subject.perform
    end

    it 'deletes old list status' do
      expect { list_status_old.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'does not delete recent status' do
      expect { list_status_recent.reload }.to_not raise_error
    end

    it 'statuses are remain' do
      expect { local_status_old }.to_not raise_error
    end
  end
end
