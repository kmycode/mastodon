# frozen_string_literal: true

require 'rails_helper'

describe ActivityPub::FetchInstanceInfoWorker do
  subject { described_class.new }

  let(:wellknown_nodeinfo) do
    {
      links: [
        {
          rel: 'http://nodeinfo.diaspora.software/ns/schema/2.0',
          href: 'https://example.com/nodeinfo/2.0',
        },
      ],
    }
  end

  let(:nodeinfo) do
    {
      version: '2.0',
      software: {
        name: 'mastodon',
        version: '4.2.0-beta1',
      },
      protocols: ['activitypub'],
    }
  end

  let(:wellknown_nodeinfo_json) { Oj.dump(wellknown_nodeinfo) }
  let(:nodeinfo_json) { Oj.dump(nodeinfo) }

  context 'when success' do
    before do
      stub_request(:get, 'https://example.com/.well-known/nodeinfo').to_return(status: 200, body: wellknown_nodeinfo_json)
      stub_request(:get, 'https://example.com/nodeinfo/2.0').to_return(status: 200, body: nodeinfo_json)
      Fabricate(:account, domain: 'example.com')
      Instance.refresh
    end

    it 'performs a mastodon instance' do
      subject.perform('example.com')

      info = InstanceInfo.find_by(domain: 'example.com')
      expect(info).to_not be_nil
      expect(info.software).to eq 'mastodon'
      expect(info.version).to eq '4.2.0-beta1'
    end
  end

  context 'when update' do
    let(:new_nodeinfo) do
      {
        version: '2.0',
        software: {
          name: 'mastodon',
          version: '4.2.0-beta3',
        },
        protocols: ['activitypub'],
      }
    end
    let(:new_nodeinfo_json) { Oj.dump(new_nodeinfo) }

    before do
      stub_request(:get, 'https://example.com/.well-known/nodeinfo').to_return(status: 200, body: wellknown_nodeinfo_json)
      Fabricate(:account, domain: 'example.com')
      Instance.refresh
    end

    it 'does not update immediately' do
      stub_request(:get, 'https://example.com/nodeinfo/2.0').to_return(status: 200, body: nodeinfo_json)
      subject.perform('example.com')
      stub_request(:get, 'https://example.com/nodeinfo/2.0').to_return(status: 200, body: new_nodeinfo_json)
      subject.perform('example.com')

      info = InstanceInfo.find_by(domain: 'example.com')
      expect(info).to_not be_nil
      expect(info.software).to eq 'mastodon'
      expect(info.version).to eq '4.2.0-beta1'
    end

    it 'performs a mastodon instance' do
      stub_request(:get, 'https://example.com/nodeinfo/2.0').to_return(status: 200, body: nodeinfo_json)
      subject.perform('example.com')
      Rails.cache.delete('fetch_instance_info:example.com')
      stub_request(:get, 'https://example.com/nodeinfo/2.0').to_return(status: 200, body: new_nodeinfo_json)
      subject.perform('example.com')

      info = InstanceInfo.find_by(domain: 'example.com')
      expect(info).to_not be_nil
      expect(info.software).to eq 'mastodon'
      expect(info.version).to eq '4.2.0-beta3'
    end
  end

  context 'when failed' do
    before do
      stub_request(:get, 'https://example.com/.well-known/nodeinfo').to_return(status: 404)
      Fabricate(:account, domain: 'example.com')
      Instance.refresh
    end

    it 'performs a mastodon instance' do
      expect(subject.perform('example.com')).to be true

      info = InstanceInfo.find_by(domain: 'example.com')
      expect(info).to be_nil
    end

    it 'does not fetch again immediately' do
      expect(subject.perform('example.com')).to be true
      expect(subject.perform('example.com')).to be true

      expect(a_request(:get, 'https://example.com/.well-known/nodeinfo')).to have_been_made.once
    end
  end
end
