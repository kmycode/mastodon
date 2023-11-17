# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostStatusService, type: :service do
  subject { described_class.new }

  it 'creates a new status' do
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text)

    expect(status).to be_persisted
    expect(status.text).to eq text
  end

  it 'creates a new response status' do
    in_reply_to_status = Fabricate(:status)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status)

    expect(status).to be_persisted
    expect(status.text).to eq text
    expect(status.thread).to eq in_reply_to_status
  end

  context 'when scheduling a status' do
    let!(:account)         { Fabricate(:account) }
    let!(:future)          { Time.now.utc + 2.hours }
    let!(:previous_status) { Fabricate(:status, account: account) }

    it 'schedules a status' do
      status = subject.call(account, text: 'Hi future!', scheduled_at: future)
      expect(status).to be_a ScheduledStatus
      expect(status.scheduled_at).to eq future
      expect(status.params['text']).to eq 'Hi future!'
    end

    it 'does not immediately create a status' do
      media = Fabricate(:media_attachment, account: account)
      status = subject.call(account, text: 'Hi future!', media_ids: [media.id], scheduled_at: future)

      expect(status).to be_a ScheduledStatus
      expect(status.scheduled_at).to eq future
      expect(status.params['text']).to eq 'Hi future!'
      expect(status.params['media_ids']).to eq [media.id]
      expect(media.reload.status).to be_nil
      expect(Status.where(text: 'Hi future!')).to_not exist
    end

    it 'does not change statuses count' do
      expect { subject.call(account, text: 'Hi future!', scheduled_at: future, thread: previous_status) }.to_not(change { [account.statuses_count, previous_status.replies_count] })
    end
  end

  it 'creates response to the original status of boost' do
    boosted_status = Fabricate(:status)
    in_reply_to_status = Fabricate(:status, reblog: boosted_status)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status)

    expect(status).to be_persisted
    expect(status.text).to eq text
    expect(status.thread).to eq boosted_status
  end

  it 'creates a sensitive status' do
    status = create_status_with_options(sensitive: true)

    expect(status).to be_persisted
    expect(status).to be_sensitive
  end

  it 'creates a status with spoiler text' do
    spoiler_text = 'spoiler text'

    status = create_status_with_options(spoiler_text: spoiler_text)

    expect(status).to be_persisted
    expect(status.spoiler_text).to eq spoiler_text
  end

  it 'creates a sensitive status when there is a CW but no text' do
    status = subject.call(Fabricate(:account), text: '', spoiler_text: 'foo')

    expect(status).to be_persisted
    expect(status).to be_sensitive
  end

  it 'creates a status with empty default spoiler text' do
    status = create_status_with_options(spoiler_text: nil)

    expect(status).to be_persisted
    expect(status.spoiler_text).to eq ''
  end

  it 'creates a status with the given visibility' do
    status = create_status_with_options(visibility: :private)

    expect(status).to be_persisted
    expect(status.visibility).to eq 'private'
  end

  it 'creates a status with limited visibility for silenced users' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', visibility: :public)

    expect(status).to be_persisted
    expect(status.visibility).to eq 'unlisted'
  end

  it 'creates a status with the given searchability' do
    status = create_status_with_options(searchability: :public, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public'
  end

  it 'creates a status with limited searchability for silenced users' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', searchability: :public, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with limited searchability for silenced users with public_unlisted searchability' do
    status = subject.call(Fabricate(:account, silenced: true), text: 'test', searchability: :public_unlisted, visibility: :public)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with the given searchability=public / visibility=unlisted' do
    status = create_status_with_options(searchability: :public, visibility: :unlisted)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public'
  end

  it 'creates a status with the given searchability=public_unlisted / visibility=unlisted' do
    status = create_status_with_options(searchability: :public_unlisted, visibility: :unlisted)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'public_unlisted'
  end

  it 'creates a status with the given searchability=public / visibility=private' do
    status = create_status_with_options(searchability: :public, visibility: :private)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status with the given searchability=public_unlisted / visibility=private' do
    status = create_status_with_options(searchability: :public_unlisted, visibility: :private)

    expect(status).to be_persisted
    expect(status.searchability).to eq 'private'
  end

  it 'creates a status for the given application' do
    application = Fabricate(:application)

    status = create_status_with_options(application: application)

    expect(status).to be_persisted
    expect(status.application).to eq application
  end

  it 'creates a status with a language set' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text)

    expect(status.language).to eq 'en'
  end

  it 'processes mentions' do
    mention_service = instance_double(ProcessMentionsService)
    allow(mention_service).to receive(:call)
    allow(ProcessMentionsService).to receive(:new).and_return(mention_service)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(ProcessMentionsService).to have_received(:new)
    expect(mention_service).to have_received(:call).with(status, limited_type: '', circle: nil, save_records: false)
  end

  it 'mutual visibility' do
    account = Fabricate(:account)
    mutual_account = Fabricate(:account)
    other_account = Fabricate(:account)
    text = 'This is an English text.'

    mutual_account.follow!(account)
    account.follow!(mutual_account)
    other_account.follow!(account)
    status = subject.call(account, text: text, visibility: 'mutual')

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'mutual'
    expect(status.mentioned_accounts.count).to eq 1
    expect(status.mentioned_accounts.first.id).to eq mutual_account.id
  end

  it 'limited visibility and direct searchability' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'mutual', searchability: 'public')

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.searchability).to eq 'direct'
  end

  it 'personal visibility with mutual' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'mutual')

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.mentioned_accounts.count).to eq 0
  end

  it 'circle visibility' do
    account = Fabricate(:account)
    circle_account = Fabricate(:account)
    other_account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    circle_account.follow!(account)
    other_account.follow!(account)
    circle.accounts << circle_account
    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
    expect(status.mentioned_accounts.count).to eq 1
    expect(status.mentioned_accounts.first.id).to eq circle_account.id
  end

  it 'circle post with limited visibility' do
    account = Fabricate(:account)
    circle_account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    circle_account.follow!(account)
    circle.accounts << circle_account
    status = subject.call(account, text: text, visibility: 'limited', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
  end

  it 'limited visibility without circle' do
    account = Fabricate(:account)
    text = 'This is an English text.'

    expect { subject.call(account, text: text, visibility: 'limited') }.to raise_exception ActiveRecord::RecordInvalid
  end

  it 'personal visibility with circle' do
    account = Fabricate(:account)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text.'

    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'personal'
    expect(status.mentioned_accounts.count).to eq 0
  end

  it 'using empty circle but with mention' do
    account = Fabricate(:account)
    Fabricate(:account, username: 'bob', domain: nil)
    circle = Fabricate(:circle, account: account)
    text = 'This is an English text. @bob'

    status = subject.call(account, text: text, visibility: 'circle', circle_id: circle.id)

    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'circle'
    expect(status.mentioned_accounts.count).to eq 1
  end

  it 'creates a new response status to limited post' do
    in_reply_to_status = Fabricate(:status, visibility: :limited)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status)

    expect(status).to be_persisted
    expect(status.thread).to eq in_reply_to_status
    expect(status.visibility).to eq 'limited'
    expect(status.limited_scope).to eq 'reply'
  end

  it 'creates a new direct message to limited post' do
    in_reply_to_status = Fabricate(:status, visibility: :limited)
    account = Fabricate(:account)
    text = 'test status update'

    status = subject.call(account, text: text, thread: in_reply_to_status, visibility: :direct)

    expect(status).to be_persisted
    expect(status.thread).to eq in_reply_to_status
    expect(status.visibility).to eq 'direct'
  end

  it 'safeguards mentions' do
    account = Fabricate(:account)
    mentioned_account = Fabricate(:account, username: 'alice')
    unexpected_mentioned_account = Fabricate(:account, username: 'bob')

    expect do
      subject.call(account, text: '@alice hm, @bob is really annoying lately', allowed_mentions: [mentioned_account.id])
    end.to raise_error(an_instance_of(PostStatusService::UnexpectedMentionsError).and(having_attributes(accounts: [unexpected_mentioned_account])))
  end

  it 'processes duplicate mentions correctly' do
    account = Fabricate(:account)
    Fabricate(:account, username: 'alice')

    expect do
      subject.call(account, text: '@alice @alice @alice hey @alice')
    end.to_not raise_error
  end

  it 'processes hashtags' do
    hashtags_service = instance_double(ProcessHashtagsService)
    allow(hashtags_service).to receive(:call)
    allow(ProcessHashtagsService).to receive(:new).and_return(hashtags_service)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(ProcessHashtagsService).to have_received(:new)
    expect(hashtags_service).to have_received(:call).with(status)
  end

  it 'gets distributed' do
    allow(DistributionWorker).to receive(:perform_async)
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)

    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(DistributionWorker).to have_received(:perform_async).with(status.id)
    expect(ActivityPub::DistributionWorker).to have_received(:perform_async).with(status.id)
  end

  it 'gets distributed when personal post' do
    allow(DistributionWorker).to receive(:perform_async)
    allow(ActivityPub::DistributionWorker).to receive(:perform_async)

    account = Fabricate(:account)

    empty_circle = Fabricate(:circle, account: account)
    status = subject.call(account, text: 'test status update', visibility: 'circle', circle_id: empty_circle.id)

    expect(DistributionWorker).to have_received(:perform_async).with(status.id)
    expect(ActivityPub::DistributionWorker).to_not have_received(:perform_async).with(status.id)
  end

  it 'crawls links' do
    allow(LinkCrawlWorker).to receive(:perform_async)
    account = Fabricate(:account)

    status = subject.call(account, text: 'test status update')

    expect(LinkCrawlWorker).to have_received(:perform_async).with(status.id)
  end

  it 'attaches the given media to the created status' do
    account = Fabricate(:account)
    media = Fabricate(:media_attachment, account: account)

    status = subject.call(
      account,
      text: 'test status update',
      media_ids: [media.id]
    )

    expect(media.reload.status).to eq status
  end

  it 'does not attach media from another account to the created status' do
    account = Fabricate(:account)
    media = Fabricate(:media_attachment, account: Fabricate(:account))

    subject.call(
      account,
      text: 'test status update',
      media_ids: [media.id]
    )

    expect(media.reload.status).to be_nil
  end

  it 'does not allow attaching more than 4 files' do
    account = Fabricate(:account)

    expect do
      subject.call(
        account,
        text: 'test status update',
        media_ids: [
          Fabricate(:media_attachment, account: account),
          Fabricate(:media_attachment, account: account),
          Fabricate(:media_attachment, account: account),
          Fabricate(:media_attachment, account: account),
          Fabricate(:media_attachment, account: account),
        ].map(&:id)
      )
    end.to raise_error(
      Mastodon::ValidationError,
      I18n.t('media_attachments.validations.too_many')
    )
  end

  it 'does not allow attaching both videos and images' do
    account = Fabricate(:account)
    video   = Fabricate(:media_attachment, type: :video, account: account)
    image   = Fabricate(:media_attachment, type: :image, account: account)

    video.update(type: :video)

    expect do
      subject.call(
        account,
        text: 'test status update',
        media_ids: [
          video,
          image,
        ].map(&:id)
      )
    end.to raise_error(
      Mastodon::ValidationError,
      I18n.t('media_attachments.validations.images_and_video')
    )
  end

  it 'returns existing status when used twice with idempotency key' do
    account = Fabricate(:account)
    status1 = subject.call(account, text: 'test', idempotency: 'meepmeep')
    status2 = subject.call(account, text: 'test', idempotency: 'meepmeep')
    expect(status2.id).to eq status1.id
  end

  describe 'ng word is set' do
    it 'hit ng words' do
      account = Fabricate(:account)
      text = 'ng word test'
      Form::AdminSettings.new(ng_words: 'test').save

      expect { subject.call(account, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'not hit ng words' do
      account = Fabricate(:account)
      text = 'ng word aiueo'
      Form::AdminSettings.new(ng_words: 'test').save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for mention' do
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      expect { subject.call(account, text: text) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for mention but local posts are not checked' do
      account = Fabricate(:account)
      Fabricate(:account, username: 'ohagi', domain: nil)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '0').save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for mention to follower' do
      account = Fabricate(:account)
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test @ohagi'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'hit ng words for reply' do
      account = Fabricate(:account)
      text = 'ng word test'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      expect { subject.call(account, text: text, thread: Fabricate(:status)) }.to raise_error(Mastodon::ValidationError)
    end

    it 'hit ng words for reply to follower' do
      account = Fabricate(:account)
      mentioned = Fabricate(:account, username: 'ohagi', domain: nil)
      mentioned.follow!(account)
      text = 'ng word test'
      Form::AdminSettings.new(ng_words_for_stranger_mention: 'test', stranger_mention_from_local_ng: '1').save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.text).to eq text
    end

    it 'using hashtag under limit' do
      account = Fabricate(:account)
      text = '#a #b'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      status = subject.call(account, text: text)

      expect(status).to be_persisted
      expect(status.tags.count).to eq 2
      expect(status.text).to eq text
    end

    it 'using hashtag over limit' do
      account = Fabricate(:account)
      text = '#a #b #c'
      Form::AdminSettings.new(post_hash_tags_max: 2).save

      expect { subject.call(account, text: text) }.to raise_error Mastodon::ValidationError
    end
  end

  def create_status_with_options(**options)
    subject.call(Fabricate(:account), options.merge(text: 'test'))
  end
end
