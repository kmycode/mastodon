# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InstanceInfo do
  describe '.emoji_reaction_availables_map' do
    subject { described_class.emoji_reaction_available?('example.com') }

    it 'availables if features contains emoji_reaction' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon', data: { metadata: { features: ['emoji_reaction'] } })
      expect(subject).to be true
    end

    it 'unavailables if features does not contain emoji_reaction' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon', data: { metadata: { features: ['ohagi'] } })
      expect(subject).to be false
    end

    it 'unavailables if features is not valid' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon', data: { metadata: { features: 'good_for_ohagi' } })
      expect(subject).to be false
    end

    it 'unavailables if features is nil' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon', data: { metadata: { features: nil } })
      expect(subject).to be false
    end

    it 'unavailables if mastodon server' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon')
      expect(subject).to be false
    end

    it 'availables if misskey server' do
      Fabricate(:instance_info, domain: 'example.com', software: 'misskey')
      expect(subject).to be true
    end

    it 'unavailables if old mastodon server' do
      Fabricate(:instance_info, domain: 'example.com', software: 'mastodon', data: { metadata: [] })
      expect(subject).to be false
    end
  end
end
