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
    let(:status_text) { 'I ate an apple.' }
    let(:searchability) { :public }

    let(:alice) { Fabricate(:user).account }
    let(:account) { alice }
    let!(:status) { Fabricate(:status, text: status_text, account: alice, searchability: searchability) }

    before do
      alice.update!(username: 'alice')
      StatusesIndex.import!
      PublicStatusesIndex.import!
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

    it_behaves_like 'hit status', 'when search with word', 'apple'
    it_behaves_like 'hit status', 'when search with multiple words', 'apple ate'
    it_behaves_like 'does not hit status', 'when search with multiple words but does not hit half', 'apple kill'
    # it_behaves_like 'hit status', 'when search with letter in word', 'p' # available only Japanese sudachi
    # it_behaves_like 'does not hit status', 'when double quote search with letter in word', '"p"' # available only Japanese sudachi
    it_behaves_like 'hit status', 'when search with fixed word', '"apple"'
    # it_behaves_like 'hit status', 'when double quote search with multiple letter in word', 'p e'  # available only Japanese sudachi
    it_behaves_like 'does not hit status', 'when double quote search with multiple letter in word but does not contain half', 'q p'
    it_behaves_like 'hit status', 'when specify user name', 'apple from:alice'
    it_behaves_like 'does not hit status', 'when specify not existing user name', 'apple from:ohagi'

    context 'when indexable is enabled' do
      let(:account) { Fabricate(:user).account }
      let(:alice) { Fabricate(:user, account: Fabricate(:account, indexable: true)).account }
      let(:searchability) { nil }

      it_behaves_like 'hit status', 'when scope is all statuses', 'apple'
      it_behaves_like 'does not hit status', 'when in:library is specified', 'apple in:library'
      it_behaves_like 'hit status', 'when in:public is specified', 'apple in:public'

      context 'with public searchability' do
        let(:searchability) { :public }

        it_behaves_like 'hit status', 'when scope is all public_searchability statuses', 'apple in:library'
      end
    end

    context 'when in:following is specified' do
      let(:following) { Fabricate(:user).account }
      let(:other) { Fabricate(:user).account }

      before do
        following.follow!(alice)
      end

      context 'with myself' do
        let(:account) { alice }

        it_behaves_like 'does not hit status', 'when search with following', 'in:following apple'
      end

      context 'with following' do
        let(:account) { following }

        it_behaves_like 'hit status', 'when search with following', 'in:following apple'
      end

      context 'without following' do
        let(:account) { other }

        it_behaves_like 'does not hit status', 'when search with following', 'in:following apple'
      end
    end

    context 'when reverse_search_quote is enabled' do
      before do
        alice.user.update!(settings: { reverse_search_quote: true })
      end

      it_behaves_like 'does not hit status', 'when search with letter in word', 'p'
      # it_behaves_like 'hit status', 'when double quote search with letter in word', '"p"' # available only Japanese sudachi
      it_behaves_like 'hit status', 'when search with word', 'apple'
    end
  end
end
