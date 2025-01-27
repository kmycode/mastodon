# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'Status::Visibility' do
  describe 'Validations' do
    context 'when status is a reblog' do
      subject { Fabricate.build :status, reblog: Fabricate(:status) }

      it { is_expected.to allow_values('public', 'unlisted', 'private').for(:visibility) }
      it { is_expected.to_not allow_values('direct', 'limited').for(:visibility) }
    end

    context 'when status is not reblog' do
      subject { Fabricate.build :status, reblog_of_id: nil }

      it { is_expected.to allow_values('public', 'unlisted', 'private', 'direct', 'limited').for(:visibility) }
    end
  end

  describe 'Scopes' do
    let!(:direct_status) { Fabricate :status, visibility: :direct }
    let!(:limited_status) { Fabricate :status, visibility: :limited }
    let!(:private_status) { Fabricate :status, visibility: :private }
    let!(:public_status) { Fabricate :status, visibility: :public }
    let!(:unlisted_status) { Fabricate :status, visibility: :unlisted }

    describe '.list_eligible_visibility' do
      it 'returns appropriate records' do
        expect(Status.list_eligible_visibility)
          .to include(
            private_status,
            public_status,
            unlisted_status
          )
          .and not_include(direct_status)
          .and not_include(limited_status)
      end
    end

    describe '.distributable_visibility' do
      it 'returns appropriate records' do
        expect(Status.distributable_visibility)
          .to include(
            public_status,
            unlisted_status
          )
          .and not_include(private_status)
          .and not_include(direct_status)
          .and not_include(limited_status)
      end
    end

    describe '.not_direct_visibility' do
      it 'returns appropriate records' do
        expect(Status.not_direct_visibility)
          .to include(
            limited_status,
            private_status,
            public_status,
            unlisted_status
          )
          .and not_include(direct_status)
      end
    end
  end

  describe 'Callbacks' do
    describe 'Setting visibility in before validation' do
      subject { Fabricate.build :status, visibility: nil }

      context 'when explicit value is set' do
        before { subject.visibility = :public }

        it 'does not change' do
          expect { subject.valid? }
            .to_not change(subject, :visibility)
        end
      end

      context 'when status is a reblog' do
        before { subject.reblog = Fabricate(:status, visibility: :public) }

        it 'changes to match the reblog' do
          expect { subject.valid? }
            .to change(subject, :visibility).to('public')
        end
      end

      context 'when account is locked' do
        before { subject.account = Fabricate.build(:account, locked: true) }

        it 'changes to private' do
          expect { subject.valid? }
            .to change(subject, :visibility).to('private')
        end
      end

      context 'when account is not locked' do
        before { subject.account = Fabricate.build(:account, locked: false) }

        it 'changes to public' do
          expect { subject.valid? }
            .to change(subject, :visibility).to('public')
        end
      end
    end
  end

  describe '.selectable_visibilities' do
    it 'returns options available for default privacy selection' do
      expect(Status.selectable_visibilities)
        .to match(%w(public public_unlisted login unlisted private))
    end
  end

  describe '#hidden?' do
    subject { Status.new }

    context 'when visibility is private' do
      before { subject.visibility = :private }

      it { is_expected.to be_hidden }
    end

    context 'when visibility is direct' do
      before { subject.visibility = :direct }

      it { is_expected.to be_hidden }
    end

    context 'when visibility is limited' do
      before { subject.visibility = :limited }

      it { is_expected.to be_hidden }
    end

    context 'when visibility is public' do
      before { subject.visibility = :public }

      it { is_expected.to_not be_hidden }
    end

    context 'when visibility is unlisted' do
      before { subject.visibility = :unlisted }

      it { is_expected.to_not be_hidden }
    end
  end

  describe '#distributable?' do
    subject { Status.new }

    context 'when visibility is public' do
      before { subject.visibility = :public }

      it { is_expected.to be_distributable }
    end

    context 'when visibility is unlisted' do
      before { subject.visibility = :unlisted }

      it { is_expected.to be_distributable }
    end

    context 'when visibility is private' do
      before { subject.visibility = :private }

      it { is_expected.to_not be_distributable }
    end

    context 'when visibility is direct' do
      before { subject.visibility = :direct }

      it { is_expected.to_not be_distributable }
    end

    context 'when visibility is limited' do
      before { subject.visibility = :limited }

      it { is_expected.to_not be_distributable }
    end
  end

  describe '#compute_searchability' do
    subject { Fabricate(:status, account: account, searchability: status_searchability) }

    let(:account_searchability) { :public }
    let(:status_searchability) { :public }
    let(:account_domain) { 'example.com' }
    let(:silenced_at) { nil }
    let(:account) { Fabricate(:account, domain: account_domain, searchability: account_searchability, silenced_at: silenced_at) }

    context 'when public-public' do
      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end
    end

    context 'when public-public but silenced' do
      let(:silenced_at) { Time.now.utc }

      it 'returns private' do
        expect(subject.compute_searchability).to eq 'private'
      end
    end

    context 'when public-public_unlisted but silenced' do
      let(:silenced_at) { Time.now.utc }
      let(:status_searchability) { :public_unlisted }

      it 'returns private' do
        expect(subject.compute_searchability).to eq 'private'
      end
    end

    context 'when public-public_unlisted' do
      let(:status_searchability) { :public_unlisted }

      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end

      it 'returns public_unlisted for local' do
        expect(subject.compute_searchability_local).to eq 'public_unlisted'
      end
    end

    context 'when public-private' do
      let(:status_searchability) { :private }

      it 'returns private' do
        expect(subject.compute_searchability).to eq 'private'
      end
    end

    context 'when public-direct' do
      let(:status_searchability) { :direct }

      it 'returns direct' do
        expect(subject.compute_searchability).to eq 'direct'
      end
    end

    context 'when private-public' do
      let(:account_searchability) { :private }

      it 'returns private' do
        expect(subject.compute_searchability).to eq 'private'
      end
    end

    context 'when direct-public' do
      let(:account_searchability) { :direct }

      it 'returns direct' do
        expect(subject.compute_searchability).to eq 'direct'
      end
    end

    context 'when limited-public' do
      let(:account_searchability) { :limited }

      it 'returns limited' do
        expect(subject.compute_searchability).to eq 'limited'
      end
    end

    context 'when private-limited' do
      let(:account_searchability) { :private }
      let(:status_searchability) { :limited }

      it 'returns limited' do
        expect(subject.compute_searchability).to eq 'limited'
      end
    end

    context 'when private-public of local account' do
      let(:account_searchability) { :private }
      let(:account_domain) { nil }
      let(:status_searchability) { :public }

      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end
    end

    context 'when direct-public of local account' do
      let(:account_searchability) { :direct }
      let(:account_domain) { nil }
      let(:status_searchability) { :public }

      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end
    end

    context 'when limited-public of local account' do
      let(:account_searchability) { :limited }
      let(:account_domain) { nil }
      let(:status_searchability) { :public }

      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end
    end

    context 'when public-public_unlisted of local account' do
      let(:account_searchability) { :public }
      let(:account_domain) { nil }
      let(:status_searchability) { :public_unlisted }

      it 'returns public' do
        expect(subject.compute_searchability).to eq 'public'
      end

      it 'returns public_unlisted for local' do
        expect(subject.compute_searchability_local).to eq 'public_unlisted'
      end

      it 'returns private for activitypub' do
        expect(subject.compute_searchability_activitypub).to eq 'private'
      end
    end
  end
end
