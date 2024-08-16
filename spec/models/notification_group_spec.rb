# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationGroup do
  subject { described_class.from_notification(notification) }

  context 'when emoji reaction notifications' do
    let(:target_status)  { Fabricate(:status) }
    let(:alice)          { Fabricate(:account) }
    let(:bob)            { Fabricate(:account) }
    let(:ohagi)          { Fabricate(:account) }
    let(:custom_emoji)   { Fabricate(:custom_emoji) }
    let(:emoji_reaction) { Fabricate(:emoji_reaction, account: alice, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji) }
    let(:notification)   { Fabricate(:notification, account: target_status.account, activity: emoji_reaction, group_key: group_key) }
    let(:group_key)      { 5 }

    it 'with single emoji_reaction' do
      group = subject.emoji_reaction_groups.first

      expect(group).to_not be_nil
      expect(group.emoji_reaction.id).to eq emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id)
    end

    it 'with multiple reactions' do
      second = Fabricate(:emoji_reaction, account: bob, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji)
      Fabricate(:notification, account: target_status.account, activity: second, group_key: group_key)

      group = subject.emoji_reaction_groups.first

      expect(group).to_not be_nil
      expect([emoji_reaction.id, second.id]).to include group.emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id, bob.id)
    end

    it 'with multiple reactions and multiple emojis' do
      second = Fabricate(:emoji_reaction, account: bob, status: target_status, name: custom_emoji.shortcode, custom_emoji: custom_emoji)
      Fabricate(:notification, account: target_status.account, activity: second, group_key: group_key)
      third = Fabricate(:emoji_reaction, account: ohagi, status: target_status, name: '😀')
      Fabricate(:notification, account: target_status.account, activity: third, group_key: group_key)

      group = subject.emoji_reaction_groups.find { |g| g.emoji_reaction.name == custom_emoji.shortcode }
      second_group = subject.emoji_reaction_groups.find { |g| g.emoji_reaction.name == '😀' }

      expect(group).to_not be_nil
      expect([emoji_reaction.id, second.id]).to include group.emoji_reaction.id
      expect(group.sample_accounts.map(&:id)).to contain_exactly(alice.id, bob.id)

      expect(second_group).to_not be_nil
      expect(third.id).to eq second_group.emoji_reaction.id
      expect(second_group.sample_accounts.map(&:id)).to contain_exactly(ohagi.id)
    end
  end
end
