# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::ProcessStatusUpdateService do
  subject { described_class.new }

  let(:thread) { nil }
  let!(:status) { Fabricate(:status, text: 'Hello world', uri: 'https://example.com/statuses/1234', account: Fabricate(:account, domain: 'example.com'), thread: thread) }
  let(:bogus_mention) { 'https://example.com/users/erroringuser' }
  let(:json_tags) do
    [
      { type: 'Hashtag', name: 'hoge' },
      { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
      { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
      { type: 'Mention', href: bogus_mention },
      { type: 'FeaturedCollection', id: ActivityPub::TagManager.instance.uri_for(featured_collection) },
    ]
  end
  let(:content) { 'Hello universe' }
  let(:payload) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Note',
      summary: 'Show more',
      content: content,
      updated: '2021-09-08T22:39:25Z',
      tag: json_tags,
    }
  end
  let(:payload_override) { {} }
  let(:json) { JSON.parse(payload.merge(payload_override).to_json) }

  let(:alice) { Fabricate(:account) }
  let(:bob) { Fabricate(:account) }
  let(:featured_collection) { Fabricate(:collection) }

  let(:mentions) { [] }
  let(:tags) { [] }
  let(:media_attachments) { [] }

  before do
    mentions.each { |(account, silent)| Fabricate(:mention, status: status, account: account, silent: silent) }
    tags.each { |t| status.tags << t }
    media_attachments.each { |m| status.media_attachments << m }
    stub_request(:get, bogus_mention).to_raise(HTTP::ConnectionError)
  end

  describe '#call' do
    it 'updates text and content warning, and schedules re-fetching broken mention' do
      subject.call(status, json, json)
      expect(status.reload)
        .to have_attributes(
          text: eq('Hello universe'),
          spoiler_text: eq('Show more')
        )
      expect(MentionResolveWorker).to have_enqueued_sidekiq_job(status.id, bogus_mention, anything)
    end

    context 'when the changes are only in sanitized-out HTML' do
      let!(:status) { Fabricate(:status, text: '<p>Hello world <a href="https://joinmastodon.org" rel="nofollow">joinmastodon.org</a></p>', account: Fabricate(:account, domain: 'example.com')) }

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          updated: '2021-09-08T22:39:25Z',
          content: '<p>Hello world <a href="https://joinmastodon.org" rel="noreferrer">joinmastodon.org</a></p>',
        }
      end

      before do
        subject.call(status, json, json)
      end

      it 'does not create any edits and does not mark status edited' do
        expect(status.reload.edits).to be_empty
        expect(status).to_not be_edited
      end
    end

    context 'when the status has not been explicitly edited' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: 'Updated text',
        }
      end

      before do
        subject.call(status, json, json)
      end

      it 'does not create any edits, mark status edited, or update text' do
        expect(status.reload.edits).to be_empty
        expect(status.reload).to_not be_edited
        expect(status.reload.text).to eq 'Hello world'
      end
    end

    context 'when the status has not been explicitly edited and features a poll' do
      let(:account) { Fabricate(:account, domain: 'example.com') }
      let!(:expiration) { 10.days.from_now.utc }
      let!(:status) do
        Fabricate(:status,
                  text: 'Hello world',
                  account: account,
                  poll_attributes: {
                    options: %w(Foo Bar),
                    account: account,
                    multiple: false,
                    hide_totals: false,
                    expires_at: expiration,
                  })
      end

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'https://example.com/foo',
          type: 'Question',
          content: 'Hello world',
          endTime: expiration.iso8601,
          oneOf: [
            poll_option_json('Foo', 4),
            poll_option_json('Bar', 3),
          ],
        }
      end

      before do
        subject.call(status, json, json)
      end

      it 'does not create any edits, mark status edited, update text but does update tallies' do
        expect(status.reload.edits).to be_empty
        expect(status.reload).to_not be_edited
        expect(status.reload.text).to eq 'Hello world'
        expect(status.poll.reload.cached_tallies).to eq [4, 3]
      end
    end

    context 'with an implicit update of a poll that has already expired' do
      let(:account) { Fabricate(:account, domain: 'example.com') }
      let!(:expiration) { 10.days.ago.utc }
      let!(:status) do
        Fabricate(:status,
                  text: 'Hello world',
                  account: account,
                  poll_attributes: {
                    options: %w(Foo Bar),
                    account: account,
                    multiple: false,
                    hide_totals: false,
                    expires_at: expiration,
                  })
      end

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'https://example.com/foo',
          type: 'Question',
          content: 'Hello world',
          endTime: expiration.iso8601,
          oneOf: [
            poll_option_json('Foo', 4),
            poll_option_json('Bar', 3),
          ],
        }
      end

      before do
        travel_to(expiration - 1.day) do
          Fabricate(:poll_vote, poll: status.poll)
        end
      end

      it 'does not re-trigger notifications' do
        expect { subject.call(status, json, json) }
          .to_not enqueue_sidekiq_job(PollExpirationNotifyWorker)
      end
    end

    context 'when the status changes a poll despite being not explicitly marked as updated' do
      let(:account) { Fabricate(:account, domain: 'example.com') }
      let!(:expiration) { 10.days.from_now.utc }
      let!(:status) do
        Fabricate(:status,
                  text: 'Hello world',
                  account: account,
                  poll_attributes: {
                    options: %w(Foo Bar),
                    account: account,
                    multiple: false,
                    hide_totals: false,
                    expires_at: expiration,
                  })
      end

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'https://example.com/foo',
          type: 'Question',
          content: 'Hello world',
          endTime: expiration.iso8601,
          oneOf: [
            poll_option_json('Foo', 4),
            poll_option_json('Bar', 3),
            poll_option_json('Baz', 3),
          ],
        }
      end

      before do
        subject.call(status, json, json)
      end

      it 'does not create any edits, mark status edited, update text, or update tallies' do
        expect(status.reload.edits).to be_empty
        expect(status.reload).to_not be_edited
        expect(status.reload.text).to eq 'Hello world'
        expect(status.poll.reload.cached_tallies).to eq [0, 0]
      end
    end

    context 'when receiving an edit older than the latest processed' do
      before do
        status.snapshot!(at_time: status.created_at, rate_limit: false)
        status.update!(text: 'Hello newer world', edited_at: Time.now.utc)
        status.snapshot!(rate_limit: false)
      end

      it 'does not create any edits or update relevant attributes' do
        expect { subject.call(status, json, json) }
          .to not_change { status.reload.edits.pluck(&:id) }
          .and(not_change { status.reload.attributes.slice('text', 'spoiler_text', 'edited_at').values })
      end
    end

    context 'with no changes at all' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: 'Hello world',
        }
      end

      before do
        subject.call(status, json, json)
      end

      it 'does not create any edits or mark status edited' do
        expect(status.reload.edits).to be_empty
        expect(status).to_not be_edited
      end
    end

    context 'with no changes and originally with no ordered_media_attachment_ids' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: 'Hello world',
        }
      end

      before do
        status.update(ordered_media_attachment_ids: nil)
        subject.call(status, json, json)
      end

      it 'does not create any edits or mark status edited' do
        expect(status.reload.edits).to be_empty
        expect(status).to_not be_edited
      end
    end

    context 'when originally without tagged objects' do
      before do
        subject.call(status, json, json)
      end

      it 'updates tags' do
        expect(status.tagged_objects.reload.map(&:object)).to contain_exactly(featured_collection)
      end
    end

    context 'when originally without tags' do
      before do
        subject.call(status, json, json)
      end

      it 'updates tags' do
        expect(status.tags.reload.map(&:name)).to eq %w(hoge)
      end
    end

    context 'when originally with tags' do
      let(:tags) { [Fabricate(:tag, name: 'test'), Fabricate(:tag, name: 'foo')] }

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          summary: 'Show more',
          content: 'Hello universe',
          updated: '2021-09-08T22:39:25Z',
          tag: [
            { type: 'Hashtag', name: 'foo' },
            { type: 'Hashtag', name: 'bar' },
            { type: 'Hashtag', name: '#2024' },
            { type: 'Hashtag', name: 'Foo Bar' },
            { type: 'Hashtag', name: 'FooBar' },
          ],
        }
      end

      before do
        status.account.featured_tags.create!(name: 'bar')
        status.account.featured_tags.create!(name: 'test')
      end

      it 'updates tags and featured tags' do
        expect { subject.call(status, json, json) }
          .to change { status.tags.reload.pluck(:name) }.from(contain_exactly('test', 'foo')).to(contain_exactly('foo', 'bar', 'foobar'))
          .and change { status.account.featured_tags.find_by(name: 'test').statuses_count }.by(-1)
          .and change { status.account.featured_tags.find_by(name: 'bar').statuses_count }.by(1)
          .and change { status.account.featured_tags.find_by(name: 'bar').last_status_at }.from(nil).to(be_present)
      end
    end

    context 'when reject tags by domain-block' do
      let(:tags) { [Fabricate(:tag, name: 'hoge'), Fabricate(:tag, name: 'ohagi')] }

      before do
        Fabricate(:domain_block, domain: 'example.com', severity: :noop, reject_hashtag: true)
        subject.call(status, json, json)
      end

      it 'updates tags' do
        expect(status.tags.reload.map(&:name)).to eq []
      end
    end

    context 'when reject mentions to stranger by domain-block' do
      let(:json_tags) do
        [
          { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
        ]
      end

      before do
        Fabricate(:domain_block, domain: 'example.com', reject_reply_exclude_followers: true, severity: :noop)
      end

      it 'updates mentions' do
        subject.call(status, json, json)

        expect(status.mentions.reload.map(&:account_id)).to eq []
      end

      it 'updates mentions when follower' do
        alice.follow!(status.account)
        subject.call(status, json, json)

        expect(status.mentions.reload.map(&:account_id)).to eq [alice.id]
      end
    end

    context 'when originally without mentions' do
      before do
        subject.call(status, json, json)
      end

      it 'updates mentions' do
        expect(status.active_mentions.reload.map(&:account_id)).to eq [alice.id]
      end
    end

    context 'when originally with mentions' do
      let(:mentions) { [[alice, false], [bob, false]] }

      before do
        subject.call(status, json, json)
      end

      it 'updates mentions' do
        expect(status.active_mentions.reload.map(&:account_id)).to eq [alice.id]
      end
    end

    context 'when originally with silent mentions' do
      let(:mentions) { [[alice, true], [bob, true]] }

      before do
        subject.call(status, json, json)
      end

      it 'updates mentions' do
        expect(status.active_mentions.reload.map(&:account_id)).to eq [alice.id]
      end
    end

    context 'when originally without media attachments' do
      before do
        stub_request(:get, 'https://example.com/foo.png').to_return(body: attachment_fixture('emojo.png'))
      end

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: 'Hello universe',
          updated: '2021-09-08T22:39:25Z',
          attachment: [
            { type: 'Image', mediaType: 'image/png', url: 'https://example.com/foo.png' },
          ],
        }
      end

      it 'updates media attachments, fetches attachment, records media change in edit' do
        subject.call(status, json, json)

        expect(status.reload.ordered_media_attachments.first)
          .to be_present
          .and(have_attributes(remote_url: 'https://example.com/foo.png'))

        expect(a_request(:get, 'https://example.com/foo.png'))
          .to have_been_made

        expect(status.edits.reload.last.ordered_media_attachment_ids)
          .to_not be_empty
      end
    end

    context 'when originally without media attachments and text is removed' do
      before do
        stub_request(:get, 'https://example.com/foo.png').to_return(body: attachment_fixture('emojo.png'))
      end

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: '',
          updated: '2021-09-08T22:39:25Z',
          attachment: [
            { type: 'Image', mediaType: 'image/png', url: 'https://example.com/foo.png' },
          ],
        }
      end

      it 'updates media attachments, fetches attachment, records media and text removal in edit' do
        subject.call(status, json, json)

        expect(status.reload.ordered_media_attachments.first)
          .to be_present
          .and(have_attributes(remote_url: 'https://example.com/foo.png'))

        expect(a_request(:get, 'https://example.com/foo.png'))
          .to have_been_made

        expect(status.edits.reload.last.ordered_media_attachment_ids)
          .to_not be_empty

        expect(status.edits.reload.last.text)
          .to_not be_present
      end
    end

    context 'when originally with media attachments' do
      let(:media_attachments) { [Fabricate(:media_attachment, remote_url: 'https://example.com/foo.png'), Fabricate(:media_attachment, remote_url: 'https://example.com/unused.png')] }

      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: 'Hello universe',
          updated: '2021-09-08T22:39:25Z',
          attachment: [
            { type: 'Image', mediaType: 'image/png', url: 'https://example.com/foo.png', name: 'A picture' },
          ],
        }
      end

      before do
        allow(RedownloadMediaWorker).to receive(:perform_async)
      end

      it 'updates the existing media attachment in-place, does not queue redownload, updates media, records media change' do
        subject.call(status, json, json)

        expect(status.media_attachments.ordered.reload.first)
          .to be_present
          .and have_attributes(
            remote_url: 'https://example.com/foo.png',
            description: 'A picture'
          )

        expect(RedownloadMediaWorker)
          .to_not have_received(:perform_async)

        expect(status.ordered_media_attachments.map(&:remote_url))
          .to eq %w(https://example.com/foo.png)

        expect(status.edits.reload.last.ordered_media_attachment_ids)
          .to_not be_empty
      end
    end

    context 'when originally with a poll' do
      before do
        poll = Fabricate(:poll, status: status)
        status.update(preloadable_poll: poll)
      end

      it 'removes poll and records media change in edit' do
        subject.call(status, json, json)

        expect(status.reload.poll).to be_nil
        expect(status.edits.reload.last.poll_options).to be_nil
      end
    end

    context 'when originally without a poll' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Question',
          content: 'Hello universe',
          updated: '2021-09-08T22:39:25Z',
          closed: true,
          oneOf: [
            { type: 'Note', name: 'Foo' },
            { type: 'Note', name: 'Bar' },
            { type: 'Note', name: 'Baz' },
          ],
        }
      end

      it 'creates a poll and records media change in edit' do
        subject.call(status, json, json)

        expect(status.reload.poll)
          .to be_present
          .and have_attributes(options: %w(Foo Bar Baz))

        expect(status.edits.reload.last.poll_options).to eq %w(Foo Bar Baz)
      end
    end

    it 'creates edit history and sets edit timestamp' do
      subject.call(status, json, json)
      expect(status.edits.reload.map(&:text))
        .to eq ['Hello world', 'Hello universe']
      expect(status.reload.edited_at.to_s)
        .to eq '2021-09-08 22:39:25 UTC'
    end

    describe 'ng word is set' do
      let(:json_tags) { [] }

      context 'when hit ng words' do
        let(:content) { 'ng word test' }

        it 'update status' do
          Fabricate(:ng_word, keyword: 'test', stranger: false)

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
        end
      end

      context 'when not hit ng words' do
        let(:content) { 'ng word aiueo' }

        it 'update status' do
          Fabricate(:ng_word, keyword: 'test', stranger: false)

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
        end
      end

      context 'when hit ng words for mention to local stranger' do
        let(:json_tags) do
          [
            { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
          ]
        end
        let(:content) { 'ng word test' }

        it 'update status' do
          Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
          expect(status.mentioned_accounts.pluck(:id)).to_not include alice.id
        end

        it 'update status when following' do
          Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
          Fabricate(:ng_word, keyword: 'test')
          alice.follow!(status.account)

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
          expect(status.mentioned_accounts.pluck(:id)).to include alice.id
        end
      end

      context 'when hit ng words for mention but local posts are not checked' do
        let(:json_tags) do
          [
            { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
          ]
        end
        let(:content) { 'ng word test' }

        it 'update status' do
          Form::AdminSettings.new(stranger_mention_from_local_ng: '0').save
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
          expect(status.mentioned_accounts.pluck(:id)).to_not include alice.id
        end
      end

      context 'when hit ng words for mention to follower' do
        let(:json_tags) do
          [
            { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
          ]
        end
        let(:content) { 'ng word test' }

        before do
          alice.follow!(status.account)
        end

        it 'update status' do
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
          expect(status.mentioned_accounts.pluck(:id)).to include alice.id
        end
      end

      context 'when hit ng words for reply' do
        let(:json_tags) do
          [
            { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
          ]
        end
        let(:content) { 'ng word test' }
        let(:thread) { Fabricate(:status, account: alice) }

        it 'update status' do
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
          expect(status.mentioned_accounts.pluck(:id)).to_not include alice.id
        end
      end

      context 'when hit ng words for reply to follower' do
        let(:json_tags) do
          [
            { type: 'Mention', href: ActivityPub::TagManager.instance.uri_for(alice) },
          ]
        end
        let(:content) { 'ng word test' }
        let(:thread) { Fabricate(:status, account: alice) }

        before do
          alice.follow!(status.account)
        end

        it 'update status' do
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
          expect(status.mentioned_accounts.pluck(:id)).to include alice.id
        end
      end

      context 'when hit ng words for reference' do
        let!(:target_status) { Fabricate(:status, account: alice) }
        let(:payload_override) do
          {
            references: {
              id: 'target_status',
              type: 'Collection',
              first: {
                type: 'CollectionPage',
                next: nil,
                partOf: 'target_status',
                items: [
                  ActivityPub::TagManager.instance.uri_for(target_status),
                ],
              },
            },
          }
        end
        let(:content) { 'ng word test' }

        it 'update status' do
          Form::AdminSettings.new(stranger_mention_from_local_ng: '1').save
          Fabricate(:ng_word, keyword: 'test')

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
          expect(status.references.pluck(:id)).to_not include target_status.id
        end

        context 'when alice follows sender' do
          before do
            alice.follow!(status.account)
          end

          it 'update status' do
            Fabricate(:ng_word, keyword: 'test')

            subject.call(status, json, json)
            expect(status.reload.text).to eq content
            expect(status.references.pluck(:id)).to include target_status.id
          end
        end
      end

      context 'when using hashtag under limit' do
        let(:json_tags) do
          [
            { type: 'Hashtag', name: 'a' },
            { type: 'Hashtag', name: 'b' },
          ]
        end
        let(:content) { 'ohagi is good' }

        it 'update status' do
          Form::AdminSettings.new(post_hash_tags_max: 2).save

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
        end
      end

      context 'when using hashtag over limit' do
        let(:json_tags) do
          [
            { type: 'Hashtag', name: 'a' },
            { type: 'Hashtag', name: 'b' },
            { type: 'Hashtag', name: 'c' },
          ]
        end
        let(:content) { 'ohagi is good' }

        it 'update status' do
          Form::AdminSettings.new(post_hash_tags_max: 2).save

          subject.call(status, json, json)
          expect(status.reload.text).to_not eq content
        end
      end
    end

    describe 'ng rule is set' do
      context 'when ng rule is match' do
        before do
          Fabricate(:ng_rule, account_domain: 'example.com', status_text: 'universe')
          subject.call(status, json, json)
        end

        it 'does not update text' do
          expect(status.reload.text).to eq 'Hello world'
          expect(status.edits.reload.map(&:text)).to eq []
        end
      end

      context 'when ng rule is not match' do
        before do
          Fabricate(:ng_rule, account_domain: 'foo.bar', status_text: 'universe')
          subject.call(status, json, json)
        end

        it 'updates text' do
          expect(status.reload.text).to eq 'Hello universe'
          expect(status.edits.reload.map(&:text)).to eq ['Hello world', 'Hello universe']
        end
      end
    end

    describe 'sensitive word is set' do
      let(:payload) do
        {
          '@context': 'https://www.w3.org/ns/activitystreams',
          id: 'foo',
          type: 'Note',
          content: content,
          updated: '2021-09-08T22:39:25Z',
          tag: json_tags,
        }
      end

      context 'when hit sensitive words' do
        let(:content) { 'ng word aiueo' }

        it 'update status' do
          Fabricate(:sensitive_word, keyword: 'test', remote: true, spoiler: false)

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
          expect(status.spoiler_text).to eq ''
        end
      end

      context 'when not hit sensitive words' do
        let(:content) { 'ng word test' }

        it 'update status' do
          Fabricate(:sensitive_word, keyword: 'test', remote: true, spoiler: false)

          subject.call(status, json, json)
          expect(status.reload.text).to eq content
          expect(status.spoiler_text).to_not eq ''
        end
      end
    end
  end

  context 'when the status has an existing unverified quote and adds an approval link through an implicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: nil) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    before do
      stub_request(:get, approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'updates the approval URI and verifies the quote' do
      expect { subject.call(status, json, json) }
        .to change(quote, :approval_uri).to(approval_uri)
        .and change(quote, :state).to('accepted')
    end
  end

  context 'when the status has an existing unverified quote and adds an approval link through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: nil) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    before do
      stub_request(:get, approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'updates the approval URI and verifies the quote' do
      expect { subject.call(status, json, json) }
        .to change(quote, :approval_uri).to(approval_uri)
        .and change(quote, :state).to('accepted')
    end
  end

  context 'when an approved quote of a local post gets updated through an explicit update, removing text' do
    let(:quoted_account) { Fabricate(:account) }
    let(:quoted_status) { Fabricate(:status, account: quoted_account, quote_approval_policy: InteractionPolicy::POLICY_FLAGS[:public] << 16) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: :accepted) }
    let(:approval_uri) { ActivityPub::TagManager.instance.approval_uri_for(quote) }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    it 'updates the quote post without changing the quote status' do
      expect { subject.call(status, json, json) }
        .to not_change(quote, :approval_uri)
        .and not_change(quote, :state).from('accepted')
        .and change(status, :text).from('Hello world').to('')
    end
  end

  context 'when an approved quote of a local post gets updated through an explicit update' do
    let(:quoted_account) { Fabricate(:account) }
    let(:quoted_status) { Fabricate(:status, account: quoted_account, quote_approval_policy: InteractionPolicy::POLICY_FLAGS[:public] << 16) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: :accepted) }
    let(:approval_uri) { ActivityPub::TagManager.instance.approval_uri_for(quote) }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    it 'updates the quote post without changing the quote status' do
      expect { subject.call(status, json, json) }
        .to not_change(quote, :approval_uri)
        .and not_change(quote, :state).from('accepted')
        .and change(status, :text).from('Hello world').to('Hello universe')
    end
  end

  context 'when an unapproved quote of a local post gets updated through an explicit update and claims approval' do
    let(:quoted_account) { Fabricate(:account) }
    let(:quoted_status) { Fabricate(:status, account: quoted_account, quote_approval_policy: 0) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, state: :rejected) }
    let(:approval_uri) { ActivityPub::TagManager.instance.approval_uri_for(quote) }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    it 'updates the quote post without changing the quote status' do
      expect { subject.call(status, json, json) }
        .to not_change(quote, :approval_uri)
        .and not_change(quote, :state).from('rejected')
        .and change(status, :text).from('Hello world').to('Hello universe')
    end
  end

  context 'when the status has an existing verified quote and removes an approval link through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    it 'removes the approval URI and unverifies the quote' do
      expect { subject.call(status, json, json) }
        .to change(quote, :approval_uri).to(nil)
      # kmyblue special spec for fedibird/misskey
      # .and change(quote, :state).to('pending')
    end
  end

  context 'when the status adds a verifiable quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    before do
      stub_request(:get, approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'updates the approval URI and verifies the quote' do
      expect { subject.call(status, json, json) }
        .to change(status, :quote).from(nil)
      expect(status.quote.approval_uri).to eq approval_uri
      expect(status.quote.state).to eq 'accepted'
    end
  end

  context 'when the status adds a verifiable quote of a reblog through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account, reblog: Fabricate(:status)) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    before do
      stub_request(:get, approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'does not update the approval URI and does not verify the quote' do
      expect { subject.call(status, json, json) }
        .to change(status, :quote).from(nil)
      expect(status.quote.approval_uri).to be_nil
      expect(status.quote.state).to_not eq 'accepted'
      expect(status.quote.quoted_status).to be_nil
    end
  end

  context 'when the status adds a unverifiable quote through an implicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    it 'does not add the quote' do
      expect { subject.call(status, json, json) }
        .to not_change(status, :quote).from(nil)
    end
  end

  context 'when the status adds a unverifiable quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    it 'updates the approval URI but does not verify the quote' do
      expect { subject.call(status, json, json) }
        .to change(status, :quote).from(nil)
      expect(status.quote.approval_uri).to be_nil
      expect(status.quote.state).to eq 'pending'
    end
  end

  context 'when the status adds a legacy quote' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        _misskey_quote: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    it 'updates the approval URI but does not verify the quote' do
      expect { subject.call(status, json, json) }
        .to change(status, :quote).from(nil)
      expect(status.quote.approval_uri).to be_nil
      expect(status.quote.state).to eq 'pending'
    end

    it 'updates the approval URI as legacy quote' do
      Setting.auto_accept_legacy_quotes = true

      expect { subject.call(status, json, json) }
        .to change(status, :quote).from(nil)
      expect(status.quote.approval_uri).to be_nil
      expect(status.quote.state).to eq 'accepted'
    end
  end

  context 'when the status removes a verified quote through an implicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
      }
    end

    it 'does not remove the quote' do
      expect { subject.call(status, json, json) }
        .to not_change { status.reload.quote }.from(quote)
    end
  end

  context 'when the status removes a verified quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
      }
    end

    it 'removes the quote' do
      expect { subject.call(status, json, json) }
        .to change { status.reload.quote }.to(nil)

      expect { quote.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when the status removes an unverified quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: nil, state: :pending) }

    let(:payload) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
      }
    end

    it 'removes the quote' do
      expect { subject.call(status, json, json) }
        .to change { status.reload.quote }.to(nil)

      expect { quote.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when the status swaps a verified quote with an unverifiable quote through an implicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:second_quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        quote: ActivityPub::TagManager.instance.uri_for(second_quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    it 'does not update the URI or the quote verification status' do
      expect { subject.call(status, json, json) }
        .to not_change { status.reload.quote }.from(quote)
        .and not_change { status.quote.quoted_status }.from(quoted_status)
        .and not_change { status.quote.state }.from('accepted')
    end
  end

  context 'when the status swaps a verified quote with an unverifiable quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:second_quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(second_quoted_status),
        quoteAuthorization: approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(quoted_status),
      }
    end

    before do
      stub_request(:get, approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'updates the URI and unverifies the quote' do
      expect { subject.call(status, json, json) }
        .to change { status.quote.quoted_status }.from(quoted_status).to(second_quoted_status)
        .and change { status.quote.state }.from('accepted')

      expect { quote.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when the status swaps a verified quote with an ID-less Tombstone through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:second_quoted_status) { Fabricate(:status, account: quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: { type: 'Tombstone' },
      }
    end

    it 'updates the URI and unverifies the quote' do
      expect { subject.call(status, json, json) }
        .to change { status.quote.quoted_status }.from(quoted_status).to(nil)
        .and change { status.quote.state }.from('accepted').to('deleted')

      expect { quote.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when the status swaps a verified quote with another verifiable quote through an explicit update' do
    let(:quoted_account) { Fabricate(:account, domain: 'quoted.example.com') }
    let(:second_quoted_account) { Fabricate(:account, domain: 'second-quoted.example.com') }
    let(:quoted_status) { Fabricate(:status, account: quoted_account) }
    let(:second_quoted_status) { Fabricate(:status, account: second_quoted_account) }
    let!(:quote) { Fabricate(:quote, status: status, quoted_status: quoted_status, approval_uri: approval_uri, state: :accepted) }
    let(:approval_uri) { 'https://quoted.example.com/approvals/1' }
    let(:second_approval_uri) { 'https://second-quoted.example.com/approvals/2' }

    let(:payload) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            '@id': 'https://w3id.org/fep/044f#quote',
            '@type': '@id',
          },
          {
            '@id': 'https://w3id.org/fep/044f#quoteAuthorization',
            '@type': '@id',
          },
        ],
        id: 'foo',
        type: 'Note',
        summary: 'Show more',
        content: 'Hello universe',
        updated: '2021-09-08T22:39:25Z',
        quote: ActivityPub::TagManager.instance.uri_for(second_quoted_status),
        quoteAuthorization: second_approval_uri,
      }
    end

    let(:quote_authorization_json) do
      {
        '@context': [
          'https://www.w3.org/ns/activitystreams',
          {
            QuoteAuthorization: 'https://w3id.org/fep/044f#QuoteAuthorization',
            gts: 'https://gotosocial.org/ns#',
            interactionPolicy: {
              '@id': 'gts:interactionPolicy',
              '@type': '@id',
            },
            interactingObject: {
              '@id': 'gts:interactingObject',
              '@type': '@id',
            },
            interactionTarget: {
              '@id': 'gts:interactionTarget',
              '@type': '@id',
            },
          },
        ],
        type: 'QuoteAuthorization',
        id: second_approval_uri,
        attributedTo: ActivityPub::TagManager.instance.uri_for(second_quoted_status.account),
        interactingObject: ActivityPub::TagManager.instance.uri_for(status),
        interactionTarget: ActivityPub::TagManager.instance.uri_for(second_quoted_status),
      }
    end

    before do
      stub_request(:get, second_approval_uri).to_return(headers: { 'Content-Type': 'application/activity+json' }, body: quote_authorization_json.to_json)
    end

    it 'updates the URI and unverifies the quote' do
      expect { subject.call(status, json, json) }
        .to change { status.quote.quoted_status }.from(quoted_status).to(second_quoted_status)
        .and change { status.quote.approval_uri }.from(approval_uri).to(second_approval_uri)
        .and(not_change { status.quote.state })

      expect { quote.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  def poll_option_json(name, votes)
    { type: 'Note', name: name, replies: { type: 'Collection', totalItems: votes } }
  end
end
