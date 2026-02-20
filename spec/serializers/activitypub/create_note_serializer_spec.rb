# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::CreateNoteSerializer do
  subject { serialized_record_json(status, described_class, adapter: ActivityPub::Adapter, options:) }

  let(:tag_manager) { ActivityPub::TagManager.instance }
  let(:status) { Fabricate(:status, created_at: Time.utc(2026, 1, 27, 15, 29, 31)) }
  let(:options) { {} }

  it 'serializes to the expected json' do
    expect(subject).to include({
      'id' => tag_manager.activity_uri_for(status),
      'type' => 'Create',
      'actor' => tag_manager.uri_for(status.account),
      'published' => '2026-01-27T15:29:31Z',
      'to' => ['https://www.w3.org/ns/activitystreams#Public'],
      'cc' => [a_string_matching(/followers$/)],
      'object' => a_hash_including(
        'id' => tag_manager.uri_for(status),
        'to' => ['https://www.w3.org/ns/activitystreams#Public'],
        'cc' => [a_string_matching(/followers$/)]
      ),
    })

    expect(subject).to_not have_key('target')
  end

  context 'with limited visibility' do
    let(:status) { Fabricate(:status, visibility: :limited, created_at: Time.utc(2026, 1, 27, 15, 29, 31)) }
    let(:options) { { use_bearcap: true } }

    before do
      status.capability_tokens.create!
    end

    it 'serializes to bearcaps' do
      capability_token = status.capability_tokens.first

      expect(subject).to include({
        'id' => tag_manager.activity_uri_for(status),
        'type' => 'Create',
        'actor' => tag_manager.uri_for(status.account),
        'published' => '2026-01-27T15:29:31Z',
        'object' => "bear:?#{{ u: tag_manager.uri_for(status.proper), t: capability_token.token }.to_query}",
      })
    end
  end

  context 'with unlisted post for misskey' do
    let(:user) { Fabricate(:user) }
    let(:status) { Fabricate(:status, account: user.account, visibility: :unlisted, created_at: Time.utc(2026, 1, 27, 15, 29, 31)) }

    before do
      user.settings['reject_unlisted_subscription'] = true
      user.save!
    end

    it 'serializes to the expected json' do
      expect(subject).to include({
        'id' => tag_manager.activity_uri_for(status),
        'type' => 'Create',
        'actor' => tag_manager.uri_for(status.account),
        'published' => '2026-01-27T15:29:31Z',
        'to' => [a_string_matching(/followers$/)],
        'cc' => ['https://www.w3.org/ns/activitystreams#Public'],
        'object' => a_hash_including(
          'id' => tag_manager.uri_for(status),
          'to' => [a_string_matching(/followers$/)],
          'cc' => ['https://www.w3.org/ns/activitystreams#Public']
        ),
      })
    end

    context 'with misskey' do
      let(:options) { { for_misskey: true } }

      it 'serializes to the expected json' do
        expect(subject).to include({
          'id' => tag_manager.activity_uri_for(status),
          'type' => 'Create',
          'actor' => tag_manager.uri_for(status.account),
          'published' => '2026-01-27T15:29:31Z',
          'to' => [a_string_matching(/followers$/)],
          'cc' => [],
          'object' => a_hash_including(
            'id' => tag_manager.uri_for(status),
            'to' => [a_string_matching(/followers$/)],
            'cc' => []
          ),
        })
      end
    end
  end
end
