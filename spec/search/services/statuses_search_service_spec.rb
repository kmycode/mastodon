# frozen_string_literal: true

require 'rails_helper'

describe StatusesSearchService do
  describe 'a local user posts with searchability' do
    subject do
      described_class.new.call('ohagi', account, limit: 10, searchability: searchability).map(&:id)
    end

    let(:alice) { Fabricate(:user).account }
    let(:following) { Fabricate(:user).account }
    let(:reacted) { Fabricate(:user).account }
    let(:other) { Fabricate(:user).account }
    let(:account) { nil }
    let(:searchability) { :public }
    let!(:status) { Fabricate(:status, text: 'Hello, ohagi', account: alice, searchability: searchability) }

    before do
      alice.update!(indexable: true)
      following.follow!(alice)
      Fabricate(:favourite, account: reacted, status: status)
      PublicStatusesIndex.import!
      StatusesIndex.import!
    end

    context 'when public searchability' do
      let(:searchability) { :public }
      let(:account) { other }

      context 'with other account' do
        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with follower' do
        let(:account) { following }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with reacted user' do
        let(:account) { reacted }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with self' do
        let(:account) { alice }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end

    context 'when public_unlisted searchability' do
      let(:searchability) { :public_unlisted }
      let(:account) { other }

      context 'with other account' do
        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with follower' do
        let(:account) { following }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with reacted user' do
        let(:account) { reacted }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with self' do
        let(:account) { alice }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end

    context 'when private searchability' do
      let(:searchability) { :private }
      let(:account) { other }

      context 'with other account' do
        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with follower' do
        let(:account) { following }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with reacted user' do
        let(:account) { reacted }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with self' do
        let(:account) { alice }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end

    context 'when direct searchability' do
      let(:searchability) { :direct }
      let(:account) { other }

      context 'with other account' do
        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with follower' do
        let(:account) { following }

        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with reacted user' do
        let(:account) { reacted }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end

      context 'with self' do
        let(:account) { alice }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end

    context 'when limited searchability' do
      let(:searchability) { :limited }
      let(:account) { other }

      context 'with other account' do
        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with follower' do
        let(:account) { following }

        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with reacted user' do
        let(:account) { reacted }

        it 'search status' do
          expect(subject.count).to eq 0
        end
      end

      context 'with self' do
        let(:account) { alice }

        it 'search status' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end
  end

  describe 'a local user posts with search keyword' do
    subject do
      described_class.new.call(search_keyword, account, limit: 10).map(&:id)
    end

    let(:search_keyword) { 'ohagi' }
    let(:status_text) { 'りんごを食べました' }

    let(:alice) { Fabricate(:user).account }
    let(:account) { alice }
    let!(:status) { Fabricate(:status, text: status_text, account: alice, searchability: :public) }

    before do
      alice.update!(username: 'alice')
      StatusesIndex.import!
    end

    shared_examples 'hit status' do |name, keyword|
      context name do
        let(:search_keyword) { keyword }

        it 'a status hits' do
          expect(subject.count).to eq 1
          expect(subject).to include status.id
        end
      end
    end

    shared_examples 'does not hit status' do |name, keyword|
      context name do
        let(:search_keyword) { keyword }

        it 'no statuses hit' do
          expect(subject.count).to eq 0
        end
      end
    end

    it_behaves_like 'hit status', 'when search with word', 'りんご'
    it_behaves_like 'hit status', 'when search with multiple words', 'りんご 食べる'
    it_behaves_like 'does not hit status', 'when search with multiple words but does not hit half', 'りんご 茹でる'
    it_behaves_like 'hit status', 'when search with letter in word', 'ご'
    it_behaves_like 'does not hit status', 'when double quote search with letter in word', '"ご"'
    it_behaves_like 'hit status', 'when search with fixed word', '"りんご"'
    it_behaves_like 'hit status', 'when double quote search with multiple letter in word', 'り ご'
    it_behaves_like 'does not hit status', 'when double quote search with multiple letter in word but does not contain half', 'ず ご'
    it_behaves_like 'hit status', 'when specify user name', 'りんご from:alice'
    it_behaves_like 'does not hit status', 'when specify not existing user name', 'りんご from:ohagi'
  end
end
