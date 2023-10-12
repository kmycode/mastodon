# frozen_string_literal: true

require 'rails_helper'

describe NodeInfo::Serializer do # rubocop:disable RSpec/FilePath
  let(:serialization) do
    JSON.parse(
      ActiveModelSerializers::SerializableResource.new(
        record, adapter: NodeInfo::Adapter, serializer: described_class, root: 'nodeinfo'
      ).to_json
    )
  end
  let(:record) { {} }

  describe 'nodeinfo version' do
    it 'returns 2.0' do
      expect(serialization['version']).to eq '2.0'
    end
  end

  describe 'mastodon version' do
    it 'contains kmyblue' do
      expect(serialization['software']['version'].include?('kmyblue')).to be true
    end
  end

  describe 'metadata' do
    it 'returns features' do
      expect(serialization['metadata']['features']).to include 'emoji_reaction'
    end

    it 'returns nodeinfo own features' do
      expect(serialization['metadata']['features']).to include 'quote'
      expect(serialization['metadata']['features']).to_not include 'kmyblue_markdown'
    end
  end
end
