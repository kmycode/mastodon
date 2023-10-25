# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeliveryAntennaService, type: :service do
  subject { described_class.new }

  let(:ltl_enabled) { true }

  let(:last_active_at) { Time.now.utc }
  let(:last_active_at_tom) { Time.now.utc }
  let(:visibility) { :public }
  let(:searchability) { :public }
  let(:domain) { nil }
  let(:spoiler_text) { '' }
  let(:tags) { Tag.find_or_create_by_names(['hoge']) }
  let(:software) { nil }
  let(:status) do
    url = domain.present? ? 'https://example.com/status' : nil
    status = Fabricate(:status, account: alice, spoiler_text: spoiler_text, visibility: visibility, searchability: searchability, text: 'Hello my body #hoge', url: url)
    status.tags << tags.first if tags.present?
    status
  end

  let!(:alice) { Fabricate(:account, domain: domain, uri: domain ? "https://#{domain}.com/alice" : '') }
  let!(:bob)   { Fabricate(:user, current_sign_in_at: last_active_at).account }
  let!(:tom)   { Fabricate(:user, current_sign_in_at: last_active_at_tom).account }
  let!(:ohagi) { Fabricate(:user, current_sign_in_at: last_active_at).account }

  let!(:antenna)       { nil }
  let!(:empty_antenna) { nil }

  let(:mode) { :home }

  before do
    Fabricate(:instance_info, domain: domain, software: software) if domain.present? && software.present?

    bob.follow!(alice)
    alice.block!(ohagi)

    Form::AdminSettings.new(enable_local_timeline: '0').save unless ltl_enabled

    allow(redis).to receive(:publish)

    subject.call(status, false, mode: mode)
  end

  def home_feed_of(account)
    HomeFeed.new(account).get(10).map(&:id)
  end

  def list_feed_of(list)
    ListFeed.new(list).get(10).map(&:id)
  end

  def antenna_feed_of(antenna)
    AntennaFeed.new(antenna).get(10).map(&:id)
  end

  def antenna_with_account(owner, target_account, **options)
    antenna = Fabricate(:antenna, account: owner, any_accounts: false, **options)
    Fabricate(:antenna_account, antenna: antenna, account: target_account)
    antenna
  end

  def antenna_with_domain(owner, target_domain, **options)
    antenna = Fabricate(:antenna, account: owner, any_domains: false, **options)
    Fabricate(:antenna_domain, antenna: antenna, name: target_domain)
    antenna
  end

  def antenna_with_tag(owner, target_tag, **options)
    antenna = Fabricate(:antenna, account: owner, any_tags: false, **options)
    tag = Tag.find_or_create_by_names([target_tag])[0]
    Fabricate(:antenna_tag, antenna: antenna, tag: tag)
    antenna
  end

  def antenna_with_keyword(owner, target_keyword, **options)
    Fabricate(:antenna, account: owner, any_keywords: false, keywords: [target_keyword], **options)
  end

  def list(owner)
    Fabricate(:list, account: owner)
  end

  context 'with account' do
    let!(:antenna)       { antenna_with_account(bob, alice) }
    let!(:empty_antenna) { antenna_with_account(tom, bob) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'when blocked' do
    let!(:empty_antenna) { antenna_with_account(ohagi, alice) }

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'when non-used' do
    let(:last_active_at_tom) { Time.now.utc.ago(1.year) }
    let!(:empty_antenna) { antenna_with_account(tom, alice) }

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with domain' do
    let(:domain)        { 'fast.example.com' }
    let!(:antenna)       { antenna_with_domain(bob, 'fast.example.com') }
    let!(:empty_antenna) { antenna_with_domain(tom, 'ohagi.example.com') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with local domain' do
    let(:domain)         { nil }
    let!(:antenna)       { antenna_with_domain(bob, 'cb6e6126.ngrok.io') }
    let!(:empty_antenna) { antenna_with_domain(tom, 'ohagi.example.com') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end

    context 'when local timeline is disabled' do
      let(:ltl_enabled) { false }

      it 'not detecting antenna' do
        expect(antenna_feed_of(antenna)).to_not include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'with tag' do
    let!(:antenna)       { antenna_with_tag(bob, 'hoge') }
    let!(:empty_antenna) { antenna_with_tag(tom, 'hog') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with keyword' do
    let!(:antenna)       { antenna_with_keyword(bob, 'body') }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'anime') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with keyword and spoiler_text' do
    let(:spoiler_text)   { 'some self' }
    let!(:antenna)       { antenna_with_keyword(bob, 'some') }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'anime') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with keyword and spoiler_text but pick from text' do
    let(:spoiler_text)   { 'some self' }
    let!(:antenna)       { antenna_with_keyword(bob, 'body') }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'anime') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with domain and excluding account' do
    let(:domain) { 'fast.example.com' }
    let!(:antenna)       { antenna_with_domain(bob, 'fast.example.com', exclude_accounts: [tom.id]) }
    let!(:empty_antenna) { antenna_with_domain(tom, 'fast.example.com', exclude_accounts: [alice.id]) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with domain and excluding keyword' do
    let(:domain) { 'fast.example.com' }
    let!(:antenna)       { antenna_with_domain(bob, 'fast.example.com', exclude_keywords: ['aaa']) }
    let!(:empty_antenna) { antenna_with_domain(tom, 'fast.example.com', exclude_keywords: ['body']) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with domain and excluding tag' do
    let(:domain) { 'fast.example.com' }
    let!(:antenna)       { antenna_with_domain(bob, 'fast.example.com') }
    let!(:empty_antenna) { antenna_with_domain(tom, 'fast.example.com', exclude_tags: [Tag.find_or_create_by_names(['hoge']).first.id]) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'with keyword and excluding domain' do
    let(:domain)        { 'fast.example.com' }
    let!(:antenna)       { antenna_with_keyword(bob, 'body', exclude_domains: ['ohagi.example.com']) }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'body', exclude_domains: ['fast.example.com']) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end

    it 'not detecting antenna' do
      expect(antenna_feed_of(empty_antenna)).to_not include status.id
    end
  end

  context 'when multiple antennas with keyword' do
    let!(:antenna)       { antenna_with_keyword(bob, 'body') }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'body') }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
      expect(antenna_feed_of(empty_antenna)).to include status.id
    end
  end

  context 'when multiple antennas from same owner with keyword' do
    let!(:antenna)       { antenna_with_keyword(tom, 'body') }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'body') }

    [1, 2, 3, 4, 5].each do |_|
      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to include status.id
      end
    end
  end

  context 'when multiple antennas insert home with keyword' do
    let!(:antenna)       { antenna_with_keyword(bob, 'body', insert_feeds: true) }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'body', insert_feeds: true) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
      expect(home_feed_of(bob)).to include status.id
      expect(antenna_feed_of(empty_antenna)).to include status.id
      expect(home_feed_of(tom)).to include status.id
    end
  end

  context 'when multiple antennas insert list with keyword' do
    let!(:antenna)       { antenna_with_keyword(bob, 'body', insert_feeds: true, list: list(bob)) }
    let!(:empty_antenna) { antenna_with_keyword(tom, 'body', insert_feeds: true, list: list(tom)) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
      expect(list_feed_of(antenna.list)).to include status.id
      expect(antenna_feed_of(empty_antenna)).to include status.id
      expect(list_feed_of(empty_antenna.list)).to include status.id
    end
  end

  context 'with keyword and unlisted visibility by not following' do
    let!(:antenna)       { antenna_with_keyword(tom, 'body') }
    let!(:empty_antenna) { antenna_with_account(tom, alice) }
    let(:visibility)     { :unlisted }

    context 'when public searchability' do
      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
      end

      it 'not detecting antenna' do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'when public_unlisted searchability' do
      let(:searchability) { :public_unlisted }

      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
      end

      it 'not detecting antenna' do
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end

    context 'when private searchability' do
      let(:searchability) { :private }

      it 'not detecting antenna' do
        expect(antenna_feed_of(antenna)).to_not include status.id
        expect(antenna_feed_of(empty_antenna)).to_not include status.id
      end
    end
  end

  context 'with keyword and unlisted visibility by following' do
    let!(:antenna)       { antenna_with_keyword(bob, 'body') }
    let!(:empty_antenna) { antenna_with_account(bob, alice) }
    let(:visibility)     { :unlisted }

    context 'when public searchability' do
      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to include status.id
      end
    end

    context 'when public_unlisted searchability' do
      let(:searchability) { :public_unlisted }

      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to include status.id
      end
    end

    context 'when private searchability' do
      let(:searchability) { :private }

      it 'detecting antenna' do
        expect(antenna_feed_of(antenna)).to include status.id
        expect(antenna_feed_of(empty_antenna)).to include status.id
      end
    end
  end

  context 'when stl mode keyword is not working' do
    let(:mode)           { :stl }
    let!(:antenna)       { antenna_with_keyword(bob, 'anime', stl: true) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end
  end

  context 'when ltl mode keyword is not working' do
    let(:mode)           { :ltl }
    let!(:antenna)       { antenna_with_keyword(bob, 'anime', ltl: true) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end
  end

  context 'when stl mode exclude_keyword is not working' do
    let(:mode)           { :stl }
    let!(:antenna)       { antenna_with_keyword(bob, 'anime', exclude_keywords: ['body'], stl: true) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end
  end

  context 'when ltl mode exclude_keyword is not working' do
    let(:mode)           { :ltl }
    let!(:antenna)       { antenna_with_keyword(bob, 'anime', exclude_keywords: ['body'], ltl: true) }

    it 'detecting antenna' do
      expect(antenna_feed_of(antenna)).to include status.id
    end
  end
end
