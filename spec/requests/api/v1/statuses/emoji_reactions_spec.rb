# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EmojiReactions' do
  let(:user)    { Fabricate(:user) }
  let(:scopes)  { 'write:favourites' }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/statuses/:status_id/emoji_reactions' do
    subject do
      post "/api/v1/statuses/#{status.id}/emoji_reactions", headers: headers, params: { emoji: emoji }
    end

    let(:status) { Fabricate(:status) }
    let(:emoji) { '😀' }

    it_behaves_like 'forbidden for wrong scope', 'read read:favourites'

    context 'with public status' do
      it 'reacts the status successfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status, emoji)).to be true
      end

      it 'returns json with updated attributes' do
        subject

        expect(body_as_json).to match(
          a_hash_including(id: status.id.to_s, emoji_reactions_count: 1)
        )
      end
    end

    context 'with private status of not-followed account' do
      let(:status) { Fabricate(:status, visibility: :private) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end

    context 'with private status of followed account' do
      let(:status) { Fabricate(:status, visibility: :private) }

      before do
        user.account.follow!(status.account)
      end

      it 'reacts the status successfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be true
      end
    end

    context 'when local custom emoji' do
      before { Fabricate(:custom_emoji, shortcode: 'ohagi') }

      let(:emoji) { 'ohagi' }

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status, 'ohagi')).to be true
      end
    end

    context 'when remote custom emoji' do
      let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji') }
      let(:emoji) { 'ohagi@foo.bar' }

      before { Fabricate(:emoji_reaction, status: status, name: 'ohagi', custom_emoji: custom_emoji) }

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status, 'ohagi', 'foo.bar')).to be true
      end
    end

    context 'when not existing custom emoji' do
      let(:emoji) { 'ohagi' }

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(422)
      end
    end

    context 'without an authorization header' do
      let(:headers) { {} }

      it 'returns http unauthorized' do
        subject

        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'POST /api/v1/statuses/:status_id/emoji_unreaction' do
    subject do
      post "/api/v1/statuses/#{status.id}/emoji_unreaction", headers: headers, params: { emoji: emoji }
    end

    let(:status) { Fabricate(:status) }
    let(:emoji) { '😀' }

    it_behaves_like 'forbidden for wrong scope', 'read read:favourites'

    context 'with public status' do
      before do
        EmojiReactService.new.call(user.account, status, emoji)
      end

      it 'unreacts the status successfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be false
      end

      it 'returns json with updated attributes' do
        subject

        expect(body_as_json).to match(
          a_hash_including(id: status.id.to_s, emoji_reactions_count: 0)
        )
      end
    end

    context 'when the requesting user was blocked by the status author' do
      before do
        EmojiReactService.new.call(user.account, status, emoji)
        status.account.block!(user.account)
      end

      it 'unreacts the status successfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be false
      end

      it 'returns json with updated attributes' do
        subject

        expect(body_as_json).to match(
          a_hash_including(id: status.id.to_s, emoji_reactions_count: 0)
        )
      end
    end

    context 'when status is not reacted' do
      it 'returns http success' do
        subject

        expect(response).to have_http_status(200)
      end
    end

    context 'with private status that was not reacted' do
      let(:status) { Fabricate(:status, visibility: :private) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end

    context 'when local custom emoji' do
      before do
        Fabricate(:custom_emoji, shortcode: 'ohagi')
        EmojiReactService.new.call(user.account, status, emoji)
      end

      let(:emoji) { 'ohagi' }

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be false
      end
    end

    context 'when remote custom emoji' do
      let(:emoji) { 'ohagi@foo.bar' }

      before do
        custom_emoji = Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji')
        Fabricate(:emoji_reaction, name: 'ohagi', status: status, custom_emoji: custom_emoji)
        EmojiReactService.new.call(user.account, status, emoji)
      end

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be false
      end
    end

    context 'when remote custom emoji but not specified domain' do
      let(:emoji) { 'ohagi' }

      before do
        custom_emoji = Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji')
        Fabricate(:emoji_reaction, name: 'ohagi', status: status, custom_emoji: custom_emoji)
        EmojiReactService.new.call(user.account, status, 'ohagi@foo.bar')
      end

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be true
      end
    end

    context 'without specified domain and reacted same name multiple domains' do
      let(:emoji) { 'ohagi' }

      before do
        Fabricate(:custom_emoji, shortcode: 'ohagi', domain: 'foo.bar', uri: 'https://foo.bar/emoji')
        Fabricate(:custom_emoji, shortcode: 'ohagi')
        EmojiReactService.new.call(user.account, status, 'ohagi')
        EmojiReactService.new.call(user.account, status, 'ohagi@foo.bar')
      end

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(user.account.emoji_reacted?(status)).to be false
      end
    end

    context 'when not existing custom emoji' do
      let(:emoji) { 'ohagi' }

      it 'reacts the status succeessfully', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
      end
    end
  end
end
