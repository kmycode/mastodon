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
end
