# frozen_string_literal: true

require 'rails_helper'

describe StatusReachFinder do
  describe '#inboxes' do
    context 'with a local status' do
      subject { described_class.new(status) }

      let(:parent_status) { nil }
      let(:quoted_status) { nil }
      let(:visibility) { :public }
      let(:searchability) { :public }
      let(:alice) { Fabricate(:account, username: 'alice') }
      let(:status) { Fabricate(:status, account: alice, thread: parent_status, quote_of_id: quoted_status&.id, visibility: visibility, searchability: searchability) }

      context 'with a simple case' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        context 'with follower' do
          before do
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'with non-follower' do
          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when misskey case with unlisted post' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }
        let(:sender_software) { 'mastodon' }
        let(:visibility) { :unlisted }

        before do
          Fabricate(:instance_info, domain: 'foo.bar', software: sender_software)
          bob.follow!(alice)
        end

        context 'when mastodon' do
          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'when misskey with private searchability' do
          let(:sender_software) { 'misskey' }
          let(:searchability) { :private }

          it 'send status without setting' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end

          it 'send status with setting' do
            alice.user.settings.update(reject_unlisted_subscription: 'true')
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to include 'https://foo.bar/inbox'
          end
        end

        context 'when misskey with public_unlisted searchability' do
          let(:sender_software) { 'misskey' }
          let(:searchability) { :public_unlisted }

          it 'send status without setting' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end

          it 'send status with setting' do
            alice.user.settings.update(reject_unlisted_subscription: 'true')
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to include 'https://foo.bar/inbox'
          end
        end

        context 'when misskey with public searchability' do
          let(:sender_software) { 'misskey' }

          it 'send status with setting' do
            alice.user.settings.update(reject_unlisted_subscription: 'true')
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'when has distributable friend server' do
          let(:sender_software) { 'misskey' }
          let(:searchability) { :public }

          before { Fabricate(:friend_domain, domain: 'foo.bar', inbox_url: 'https://foo.bar/inbox', available: true, active_state: :accepted, passive_state: :accepted, pseudo_relay: true) }

          it 'send status without friend server' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when this server has a friend' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        context 'with follower' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :accepted)
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to include 'https://foo.bar/inbox'
          end
        end

        context 'with non-follower' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :accepted)
          end

          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'with pending' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :pending)
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'with idle' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :idle, passive_state: :accepted)
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'when unavailable' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :accepted, available: false)
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to_not include 'https://foo.bar/inbox'
          end
        end

        context 'when distributable' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', active_state: :accepted, passive_state: :accepted, pseudo_relay: true)
            bob.follow!(alice)
          end

          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to include 'https://foo.bar/inbox'
          end
        end

        context 'when distributable and not following' do
          before do
            Fabricate(:friend_domain, domain: 'foo.bar', inbox_url: 'https://foo.bar/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: true)
          end

          it 'send status' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
            expect(subject.inboxes_for_friend).to include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it contains distributable friend server' do
        before { Fabricate(:friend_domain, domain: 'foo.bar', inbox_url: 'https://foo.bar/inbox', available: true, active_state: :accepted, passive_state: :accepted, pseudo_relay: true) }

        it 'includes the inbox of the mentioned account' do
          expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          expect(subject.inboxes_for_misskey).to_not include 'https://foo.bar/inbox'
          expect(subject.inboxes_for_friend).to include 'https://foo.bar/inbox'
        end
      end

      context 'when it contains mentions of remote accounts' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          status.mentions.create!(account: bob)
        end

        it 'includes the inbox of the mentioned account' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end
      end

      context 'when it has been reblogged by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.statuses.create!(reblog: status)
        end

        it 'includes the inbox of the reblogger' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the reblogger' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it has been favourited by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.favourites.create!(status: status)
        end

        it 'includes the inbox of the favouriter' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the favouriter' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it has been replied to by a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }

        before do
          bob.statuses.create!(thread: status, text: 'Hoge')
        end

        it 'includes the inbox of the replier' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public' do
          let(:visibility) { :private }

          it 'does not include the inbox of the replier' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it is a reply to a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }
        let(:parent_status) { Fabricate(:status, account: bob) }

        it 'includes the inbox of the replied-to account' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end

        context 'when status is not public and replied-to account is not mentioned' do
          let(:visibility) { :private }

          it 'does not include the inbox of the replied-to account' do
            expect(subject.inboxes).to_not include 'https://foo.bar/inbox'
          end
        end
      end

      context 'when it is a quote to a remote account' do
        let(:bob) { Fabricate(:account, username: 'bob', domain: 'foo.bar', protocol: :activitypub, inbox_url: 'https://foo.bar/inbox') }
        let(:quoted_status) { Fabricate(:status, account: bob) }

        it 'includes the inbox of the quoted-to account' do
          expect(subject.inboxes).to include 'https://foo.bar/inbox'
        end
      end
    end

    context 'with extended domain block' do
      subject do
        described_class.new(status)
      end

      before do
        bob.follow!(alice)
        tom.follow!(alice)
        Fabricate(:domain_block, domain: 'example.com', severity: 'noop', **properties)
      end

      let(:properties) { {} }
      let(:visibility) { :public }
      let(:searchability) { :public }
      let(:dissubscribable) { false }
      let(:spoiler_text) { '' }
      let(:status) { Fabricate(:status, account: alice, visibility: visibility, searchability: searchability, spoiler_text: spoiler_text) }
      let(:alice) { Fabricate(:account, username: 'alice', dissubscribable: dissubscribable) }
      let(:bob) { Fabricate(:account, username: 'bob', domain: 'example.com', protocol: :activitypub, uri: 'https://example.com/', inbox_url: 'https://example.com/inbox') }
      let(:tom) { Fabricate(:account, username: 'tom', domain: 'tom.com', protocol: :activitypub, uri: 'https://tom.com/', inbox_url: 'https://tom.com/inbox') }

      context 'when reject_send_not_public_searchability' do
        let(:properties) { { reject_send_not_public_searchability: true } }
        let(:searchability) { :private }

        it 'does not include the inbox of blocked domain' do
          expect(subject.inboxes).to_not include 'https://example.com/inbox'
          expect(subject.inboxes).to include 'https://tom.com/inbox'
        end
      end

      context 'when reject_send_public_unlisted' do
        let(:properties) { { reject_send_public_unlisted: true } }
        let(:visibility) { :public_unlisted }

        it 'does not include the inbox of blocked domain' do
          expect(subject.inboxes).to_not include 'https://example.com/inbox'
          expect(subject.inboxes).to include 'https://tom.com/inbox'
        end

        context 'when reject_send_dissubscribable' do
          let(:properties) { { reject_send_dissubscribable: true } }
          let(:dissubscribable) { true }

          it 'does not include the inbox of blocked domain' do
            expect(subject.inboxes).to_not include 'https://example.com/inbox'
            expect(subject.inboxes).to include 'https://tom.com/inbox'
          end
        end

        context 'when reject_send_sensitive' do
          let(:properties) { { reject_send_sensitive: true } }
          let(:spoiler_text) { 'CW' }

          it 'does not include the inbox of blocked domain' do
            expect(subject.inboxes).to_not include 'https://example.com/inbox'
            expect(subject.inboxes).to include 'https://tom.com/inbox'
          end
        end
      end
    end
  end

  describe '#inboxes_for_friend and distributables' do
    subject { described_class.new(status).inboxes_for_friend }

    let(:visibility) { :public }
    let(:searchability) { :public }
    let(:alice) { Fabricate(:account, username: 'alice') }
    let(:status) { Fabricate(:status, account: alice, visibility: visibility, searchability: searchability) }

    context 'when a simple case' do
      before do
        Fabricate(:friend_domain, domain: 'abc.com', inbox_url: 'https://abc.com/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: true, available: true)
        Fabricate(:friend_domain, domain: 'def.com', inbox_url: 'https://def.com/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: true, available: true)
        Fabricate(:friend_domain, domain: 'ghi.com', inbox_url: 'https://ghi.com/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: true, available: false)
        Fabricate(:friend_domain, domain: 'jkl.com', inbox_url: 'https://jkl.com/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: false, available: true)
        Fabricate(:friend_domain, domain: 'mno.com', inbox_url: 'https://mno.com/inbox', active_state: :accepted, passive_state: :pending, pseudo_relay: true, available: true)
        Fabricate(:friend_domain, domain: 'pqr.com', inbox_url: 'https://pqr.com/inbox', active_state: :accepted, passive_state: :accepted, pseudo_relay: true, available: true)
        Fabricate(:unavailable_domain, domain: 'pqr.com')
      end

      it 'returns friend servers' do
        expect(subject).to include 'https://abc.com/inbox'
        expect(subject).to include 'https://def.com/inbox'
      end

      it 'not contains unavailable friends' do
        expect(subject).to_not include 'https://ghi.com/inbox'
      end

      it 'not contains no-relay friends' do
        expect(subject).to_not include 'https://jkl.com/inbox'
      end

      it 'not contains no-mutual friends' do
        expect(subject).to_not include 'https://mno.com/inbox'
      end

      it 'not contains unavailable domain friends' do
        expect(subject).to_not include 'https://pqr.com/inbox'
      end

      context 'when public visibility' do
        let(:visibility) { :public }
        let(:searchability) { :direct }

        it 'returns friend servers' do
          expect(subject).to_not eq []
        end
      end

      context 'when public_unlsited visibility' do
        let(:visibility) { :public_unlisted }
        let(:searchability) { :direct }

        it 'returns friend servers' do
          expect(subject).to_not eq []
        end
      end

      context 'when unlsited visibility with public searchability' do
        let(:visibility) { :unlisted }
        let(:searchability) { :public }

        it 'returns friend servers' do
          expect(subject).to_not eq []
        end
      end

      context 'when unlsited visibility with public_unlisted searchability' do
        let(:visibility) { :unlisted }
        let(:searchability) { :public_unlisted }

        it 'returns friend servers' do
          expect(subject).to_not eq []
        end
      end

      context 'when unlsited visibility with private searchability' do
        let(:visibility) { :unlisted }
        let(:searchability) { :private }

        it 'returns empty servers' do
          expect(subject).to eq []
        end
      end

      context 'when private visibility' do
        let(:visibility) { :private }

        it 'returns friend servers' do
          expect(subject).to eq []
        end
      end
    end
  end
end
