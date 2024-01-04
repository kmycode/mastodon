# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vacuum::FeedsVacuum do
  subject { described_class.new }

  describe '#perform' do
    let!(:active_user) { Fabricate(:user, current_sign_in_at: 2.days.ago) }
    let!(:inactive_user) { Fabricate(:user, current_sign_in_at: 22.days.ago) }
    let!(:list) { Fabricate(:list, account: inactive_user.account) }
    let!(:antenna) { Fabricate(:antenna, account: inactive_user.account) }

    before do
      redis.zadd(feed_key_for(inactive_user), 1, 1)
      redis.zadd(feed_key_for(active_user), 1, 1)
      redis.zadd(feed_key_for(inactive_user, 'reblogs'), 2, 2)
      redis.sadd(feed_key_for(inactive_user, 'reblogs:2'), 3)
      redis.zadd(list_key_for(list), 1, 1)
      redis.zadd(antenna_key_for(antenna), 1, 1)

      subject.perform
    end

    it 'clears feeds of inactive users and lists' do
      expect(redis.zcard(feed_key_for(inactive_user))).to eq 0
      expect(redis.zcard(feed_key_for(active_user))).to eq 1
      expect(redis.exists?(feed_key_for(inactive_user, 'reblogs'))).to be false
      expect(redis.exists?(feed_key_for(inactive_user, 'reblogs:2'))).to be false
      expect(redis.zcard(list_key_for(list))).to eq 0
      expect(redis.zcard(antenna_key_for(antenna))).to eq 0
    end
  end

  def feed_key_for(user, subtype = nil)
    FeedManager.instance.key(:home, user.account_id, subtype)
  end

  def list_key_for(list)
    FeedManager.instance.key(:list, list.id)
  end

  def antenna_key_for(antenna)
    FeedManager.instance.key(:antenna, antenna.id)
  end
end
