# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateStatusService, type: :service do
  subject { described_class.new }

  context 'when nothing changes' do
    let!(:status) { Fabricate(:status, text: 'Foo', language: 'en') }

    before do
      allow(ActivityPub::DistributionWorker).to receive(:perform_async)
      subject.call(status, status.account_id, text: 'Foo')
    end

    it 'does not create an edit' do
      expect(status.reload.edits).to be_empty
    end

    it 'does not notify anyone' do
      expect(ActivityPub::DistributionWorker).to_not have_received(:perform_async)
    end
  end

  context 'when text changes' do
    let(:status) { Fabricate(:status, text: 'Foo') }
    let(:preview_card) { Fabricate(:preview_card) }

    before do
      PreviewCardsStatus.create(status: status, preview_card: preview_card)
      subject.call(status, status.account_id, text: 'Bar')
    end

    it 'updates text' do
      expect(status.reload.text).to eq 'Bar'
    end

    it 'resets preview card' do
      expect(status.reload.preview_card).to be_nil
    end

    it 'saves edit history' do
      expect(status.edits.pluck(:text)).to eq %w(Foo Bar)
    end
  end

  context 'when content warning changes' do
    let(:status) { Fabricate(:status, text: 'Foo', spoiler_text: '') }
    let(:preview_card) { Fabricate(:preview_card) }

    before do
      PreviewCardsStatus.create(status: status, preview_card: preview_card)
      subject.call(status, status.account_id, text: 'Foo', spoiler_text: 'Bar')
    end

    it 'updates content warning' do
      expect(status.reload.spoiler_text).to eq 'Bar'
    end

    it 'saves edit history' do
      expect(status.edits.pluck(:text, :spoiler_text)).to eq [['Foo', ''], ['Foo', 'Bar']]
    end
  end

  context 'when media attachments change' do
    let!(:status) { Fabricate(:status, text: 'Foo') }
    let!(:detached_media_attachment) { Fabricate(:media_attachment, account: status.account) }
    let!(:attached_media_attachment) { Fabricate(:media_attachment, account: status.account) }

    before do
      status.media_attachments << detached_media_attachment
      subject.call(status, status.account_id, text: 'Foo', media_ids: [attached_media_attachment.id])
    end

    it 'updates media attachments' do
      expect(status.ordered_media_attachments).to eq [attached_media_attachment]
    end

    it 'does not detach detached media attachments' do
      expect(detached_media_attachment.reload.status_id).to eq status.id
    end

    it 'attaches attached media attachments' do
      expect(attached_media_attachment.reload.status_id).to eq status.id
    end

    it 'saves edit history' do
      expect(status.edits.pluck(:ordered_media_attachment_ids)).to eq [[detached_media_attachment.id], [attached_media_attachment.id]]
    end
  end

  context 'when already-attached media changes' do
    let!(:status) { Fabricate(:status, text: 'Foo') }
    let!(:media_attachment) { Fabricate(:media_attachment, account: status.account, description: 'Old description') }

    before do
      status.media_attachments << media_attachment
      subject.call(status, status.account_id, text: 'Foo', media_ids: [media_attachment.id], media_attributes: [{ id: media_attachment.id, description: 'New description' }])
    end

    it 'does not detach media attachment' do
      expect(media_attachment.reload.status_id).to eq status.id
    end

    it 'updates the media attachment description' do
      expect(media_attachment.reload.description).to eq 'New description'
    end

    it 'saves edit history' do
      expect(status.edits.map { |edit| edit.ordered_media_attachments.map(&:description) }).to eq [['Old description'], ['New description']]
    end
  end

  context 'when poll changes' do
    let(:account) { Fabricate(:account) }
    let!(:status) { Fabricate(:status, text: 'Foo', account: account, poll_attributes: { options: %w(Foo Bar), account: account, multiple: false, hide_totals: false, expires_at: 7.days.from_now }) }
    let!(:poll)   { status.poll }
    let!(:voter) { Fabricate(:account) }

    before do
      status.update(poll: poll)
      VoteService.new.call(voter, poll, [0])
      Sidekiq::Testing.fake! do
        subject.call(status, status.account_id, text: 'Foo', poll: { options: %w(Bar Baz Foo), expires_in: 5.days.to_i })
      end
    end

    it 'updates poll' do
      poll = status.poll.reload
      expect(poll.options).to eq %w(Bar Baz Foo)
    end

    it 'resets votes' do
      poll = status.poll.reload
      expect(poll.votes_count).to eq 0
      expect(poll.votes.count).to eq 0
      expect(poll.cached_tallies).to eq [0, 0, 0]
    end

    it 'saves edit history' do
      expect(status.edits.pluck(:poll_options)).to eq [%w(Foo Bar), %w(Bar Baz Foo)]
    end

    it 'requeues expiration notification' do
      poll = status.poll.reload
      expect(PollExpirationNotifyWorker).to have_enqueued_sidekiq_job(poll.id).at(poll.expires_at + 5.minutes)
    end
  end

  context 'when mentions in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:alice) { Fabricate(:account, username: 'alice') }
    let!(:bob) { Fabricate(:account, username: 'bob') }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello @alice') }

    before do
      subject.call(status, status.account_id, text: 'Hello @bob')
    end

    it 'changes mentions' do
      expect(status.active_mentions.pluck(:account_id)).to eq [bob.id]
    end

    it 'keeps old mentions as silent mentions' do
      expect(status.mentions.pluck(:account_id)).to contain_exactly(alice.id, bob.id)
    end
  end

  context 'when personal_limited mentions in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:bob) { Fabricate(:account, username: 'bob') }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello', visibility: 'circle', circle_id: Fabricate(:circle, account: account).id) }

    before do
      subject.call(status, status.account_id, text: 'Hello @bob')
    end

    it 'changes mentions' do
      expect(status.active_mentions.pluck(:account_id)).to eq [bob.id]
    end

    it 'changes visibilities' do
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'circle'
    end
  end

  context 'when personal_limited in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello', visibility: 'circle', circle_id: Fabricate(:circle, account: account).id) }

    before do
      subject.call(status, status.account_id, text: 'AAA')
    end

    it 'not changing visibilities' do
      expect(status.visibility).to eq 'limited'
      expect(status.limited_scope).to eq 'personal'
    end
  end

  context 'when hashtags in text change' do
    let!(:account) { Fabricate(:account) }
    let!(:status) { PostStatusService.new.call(account, text: 'Hello #foo') }

    before do
      subject.call(status, status.account_id, text: 'Hello #bar')
    end

    it 'changes tags' do
      expect(status.tags.pluck(:name)).to eq %w(bar)
    end
  end

  it 'notifies ActivityPub about the update' do
    status = Fabricate(:status, text: 'Foo')
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)
    subject.call(status, status.account_id, text: 'Bar')
    expect(ActivityPub::DistributionWorker).to have_received(:perform_async)
  end

  describe 'ng word is set' do
    let(:account) { Fabricate(:account) }
    let(:status) { PostStatusService.new.call(account, text: 'ohagi') }

    it 'hit ng words' do
      text = 'ng word test'
      Form::AdminSettings.new(ng_words: 'test').save

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'not hit ng words' do
      text = 'ng word aiueo'
      Form::AdminSettings.new(ng_words: 'test').save

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for mention' do
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
      expect(status.reload.text).to_not eq text
      expect(status.mentioned_accounts.pluck(:username)).to_not include 'ohagi'
    end

    it 'hit ng words for mention but local posts are not checked' do
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '0').save

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for mention to follower' do
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      status2 = subject.call(status, status.account_id, text: text)

      expect(status2).to be_persisted
      expect(status2.text).to eq text
    end

    it 'hit ng words for reply' do
      text = 'ng word test'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      status = PostStatusService.new.call(account, text: 'hello', thread: Fabricate(:status))

      expect { subject.call(status, status.account_id, text: text) }.to raise_error(Mastodon::ValidationError)
      expect(status.reload.text).to_not eq text
    end

    it 'hit ng words for reply to follower' do
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      status = PostStatusService.new.call(account, text: 'hello', thread: Fabricate(:status, account: mentioned))

      status = subject.call(status, status.account_id, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using hashtag under limit' do
      text = '#a #b'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      subject.call(status, status.account_id, text: text)

      expect(status.reload.tags.count).to eq 2
      expect(status.text).to eq text
    end

    it 'using hashtag over limit' do
      text = '#a #b #c'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      expect { subject.call(status, status.account_id, text: text) }.to raise_error Mastodon::ValidationError

      expect(status.reload.tags.count).to eq 0
      expect(status.text).to_not eq text
    end
  end
end
