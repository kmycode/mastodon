# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteAccountService, type: :service do
  shared_examples 'common behavior' do
    subject { described_class.new.call(account) }

    before do
      account.follow!(list_target_account)
      circle_target_account.follow!(account)
    end

    let!(:status) { Fabricate(:status, account: account) }
    let!(:mention) { Fabricate(:mention, account: local_follower) }
    let!(:status_with_mention) { Fabricate(:status, account: account, mentions: [mention]) }
    let!(:media_attachment) { Fabricate(:media_attachment, account: account) }
    let!(:notification) { Fabricate(:notification, account: account) }
    let!(:favourite) { Fabricate(:favourite, account: account, status: Fabricate(:status, account: local_follower)) }
    let!(:emoji_reaction) { Fabricate(:emoji_reaction, account: account, status: Fabricate(:status, account: local_follower)) }
    let!(:bookmark) { Fabricate(:bookmark, account: account) }
    let!(:poll) { Fabricate(:poll, account: account) }
    let!(:poll_vote) { Fabricate(:poll_vote, account: local_follower, poll: poll) }

    let!(:active_relationship) { Fabricate(:follow, account: account, target_account: local_follower) }
    let!(:passive_relationship) { Fabricate(:follow, account: local_follower, target_account: account) }
    let!(:endorsement) { Fabricate(:account_pin, account: local_follower, target_account: account) }

    let!(:mention_notification) { Fabricate(:notification, account: local_follower, activity: mention, type: :mention) }
    let!(:status_notification) { Fabricate(:notification, account: local_follower, activity: status, type: :status) }
    let!(:poll_notification) { Fabricate(:notification, account: local_follower, activity: poll, type: :poll) }
    let!(:favourite_notification) { Fabricate(:notification, account: local_follower, activity: favourite, type: :favourite) }
    let!(:emoji_reaction_notification) { Fabricate(:notification, account: local_follower, activity: emoji_reaction, type: :emoji_reaction) }
    let!(:follow_notification) { Fabricate(:notification, account: local_follower, activity: active_relationship, type: :follow) }

    let!(:list) { Fabricate(:list, account: account) }
    let!(:list_account) { Fabricate(:list_account, list: list, account: list_target_account) }
    let!(:list_target_account) { Fabricate(:account) }
    let!(:antenna) { Fabricate(:antenna, account: account) }
    let!(:antenna_account) { Fabricate(:antenna_account, antenna: antenna, account: list_target_account) }
    let!(:circle) { Fabricate(:circle, account: account) }
    let!(:circle_account) { Fabricate(:circle_account, circle: circle, account: circle_target_account) }
    let!(:circle_target_account) { Fabricate(:account) }
    let!(:circle_status) { Fabricate(:circle_status, circle: circle, status: Fabricate(:status, account: account, visibility: :limited)) }
    let!(:bookmark_category) { Fabricate(:bookmark_category, account: account) }
    let!(:bookmark_category_status) { Fabricate(:bookmark_category_status, bookmark_category: bookmark_category, status: bookmark.status) }

    let!(:account_note) { Fabricate(:account_note, account: account) }

    it 'deletes associated owned and target records and target notifications' do
      expect { subject }
        .to delete_associated_owned_records
        .and delete_associated_target_records
        .and delete_associated_target_notifications
    end

    def delete_associated_owned_records
      change do
        [
          account.statuses,
          account.media_attachments,
          account.notifications,
          account.favourites,
          account.emoji_reactions,
          account.bookmarks,
          account.active_relationships,
          account.passive_relationships,
          account.polls,
          account.account_notes,
        ].map(&:count)
      end.from([3, 1, 1, 1, 1, 1, 2, 2, 1, 1]).to([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    end

    it 'deletes associated owned record groups' do
      expect { subject }.to change {
        [
          account.owned_lists,
          account.antennas,
          account.circles,
          account.bookmark_categories,
        ].map(&:count)
      }.from([1, 1, 1, 1]).to([0, 0, 0, 0])
      expect { bookmark_category_status.status.reload }.to_not raise_error
      expect { antenna_account.account.reload }.to_not raise_error
      expect { circle_account.account.reload }.to_not raise_error
      expect { antenna_account.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { circle_account.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { circle_status.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { bookmark_category_status.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    def delete_associated_target_records
      change do
        [
          AccountPin.where(target_account: account),
        ].map(&:count)
      end.from([1]).to([0])
    end

    def delete_associated_target_notifications
      change do
        %w(
          poll favourite emoji_reaction status mention follow
        ).map { |type| Notification.where(type: type).count }
      end.from([1, 1, 1, 1, 1, 1]).to([0, 0, 0, 0, 0, 0])
    end
  end

  describe '#call on local account' do
    before do
      stub_request(:post, 'https://alice.com/inbox').to_return(status: 201)
      stub_request(:post, 'https://bob.com/inbox').to_return(status: 201)
    end

    let!(:remote_alice) { Fabricate(:account, inbox_url: 'https://alice.com/inbox', domain: 'alice.com', protocol: :activitypub) }
    let!(:remote_bob) { Fabricate(:account, inbox_url: 'https://bob.com/inbox', domain: 'bob.com', protocol: :activitypub) }

    include_examples 'common behavior' do
      let!(:account) { Fabricate(:account) }
      let!(:local_follower) { Fabricate(:account) }

      it 'sends a delete actor activity to all known inboxes' do
        subject
        expect(a_request(:post, 'https://alice.com/inbox')).to have_been_made.once
        expect(a_request(:post, 'https://bob.com/inbox')).to have_been_made.once
      end
    end
  end

  describe '#call on remote account' do
    before do
      stub_request(:post, 'https://alice.com/inbox').to_return(status: 201)
      stub_request(:post, 'https://bob.com/inbox').to_return(status: 201)
    end

    include_examples 'common behavior' do
      let!(:account) { Fabricate(:account, inbox_url: 'https://bob.com/inbox', protocol: :activitypub, domain: 'bob.com') }
      let!(:local_follower) { Fabricate(:account) }

      it 'sends expected activities to followed and follower inboxes' do
        subject

        expect(a_request(:post, account.inbox_url).with(
                 body:
                   hash_including({
                     'type' => 'Reject',
                     'object' => hash_including({
                       'type' => 'Follow',
                       'actor' => account.uri,
                       'object' => ActivityPub::TagManager.instance.uri_for(local_follower),
                     }),
                   })
               )).to have_been_made.once

        expect(a_request(:post, account.inbox_url).with(
                 body: hash_including({
                   'type' => 'Undo',
                   'object' => hash_including({
                     'type' => 'Follow',
                     'actor' => ActivityPub::TagManager.instance.uri_for(local_follower),
                     'object' => account.uri,
                   }),
                 })
               )).to have_been_made.once
      end
    end
  end
end
