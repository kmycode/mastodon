# frozen_string_literal: true

require 'rails_helper'

describe REST::InstanceSerializer do
  let(:serialization) do
    JSON.parse(
      ActiveModelSerializers::SerializableResource.new(
        record, serializer: described_class
      ).to_json
    )
  end
  let(:record) { InstancePresenter.new }

  describe 'usage' do
    it 'returns recent usage data' do
      expect(serialization['usage']).to eq({ 'users' => { 'active_month' => 0 } })
    end
  end

  describe 'fedibird_capabilities' do
    it 'returns fedibird_capabilities' do
      expect(serialization['fedibird_capabilities']).to include 'emoji_reaction'
    end
  end
end
