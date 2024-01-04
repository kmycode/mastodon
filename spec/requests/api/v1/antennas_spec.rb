# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Antennas' do
  let(:user)    { Fabricate(:user) }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:scopes)  { 'read:lists write:lists' }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'GET /api/v1/antennas' do
    subject do
      get '/api/v1/antennas', headers: headers
    end

    let!(:antennas) do
      [
        Fabricate(:antenna, account: user.account, title: 'first antenna'),
        Fabricate(:antenna, account: user.account, title: 'second antenna', with_media_only: true),
        Fabricate(:antenna, account: user.account, title: 'third antenna', stl: true),
        Fabricate(:antenna, account: user.account, title: 'fourth antenna', ignore_reblog: true),
      ]
    end

    let(:expected_response) do
      antennas.map do |antenna|
        {
          id: antenna.id.to_s,
          title: antenna.title,
          with_media_only: antenna.with_media_only,
          ignore_reblog: antenna.ignore_reblog,
          stl: antenna.stl,
          ltl: antenna.ltl,
          insert_feeds: antenna.insert_feeds,
          list: nil,
          accounts_count: 0,
          domains_count: 0,
          tags_count: 0,
          keywords_count: 0,
        }
      end
    end

    before do
      Fabricate(:antenna)
    end

    it_behaves_like 'forbidden for wrong scope', 'write write:lists'

    it 'returns the expected antennas', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to match_array(expected_response)
    end
  end

  describe 'GET /api/v1/antennas/:id' do
    subject do
      get "/api/v1/antennas/#{antenna.id}", headers: headers
    end

    let(:antenna) { Fabricate(:antenna, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'write write:lists'

    it 'returns the requested antenna correctly', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to eq({
        id: antenna.id.to_s,
        title: antenna.title,
        with_media_only: antenna.with_media_only,
        ignore_reblog: antenna.ignore_reblog,
        stl: antenna.stl,
        ltl: antenna.ltl,
        insert_feeds: antenna.insert_feeds,
        list: nil,
        accounts_count: 0,
        domains_count: 0,
        tags_count: 0,
        keywords_count: 0,
      })
    end

    context 'when the antenna belongs to a different user' do
      let(:antenna) { Fabricate(:antenna) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end

    context 'when the antenna does not exist' do
      it 'returns http not found' do
        get '/api/v1/antennas/-1', headers: headers

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/antennas' do
    subject do
      post '/api/v1/antennas', headers: headers, params: params
    end

    let(:params) { { title: 'my antenna', ltl: 'true' } }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'returns the new antenna', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to match(a_hash_including(title: 'my antenna', ltl: true))
      expect(Antenna.where(account: user.account).count).to eq(1)
    end

    context 'when a title is not given' do
      let(:params) { { title: '' } }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'PUT /api/v1/antennas/:id' do
    subject do
      put "/api/v1/antennas/#{antenna.id}", headers: headers, params: params
    end

    let(:antenna) { Fabricate(:antenna, account: user.account, title: 'my antenna') }
    let(:params) { { title: 'antenna', ignore_reblog: 'true', insert_feeds: 'true' } }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'returns the updated antenna and updates values', :aggregate_failures do
      expect { subject }
        .to change_antenna_title
        .and change_antenna_ignore_reblog
        .and change_antenna_insert_feeds

      expect(response).to have_http_status(200)
      antenna.reload

      expect(body_as_json).to eq({
        id: antenna.id.to_s,
        title: antenna.title,
        with_media_only: antenna.with_media_only,
        ignore_reblog: antenna.ignore_reblog,
        stl: antenna.stl,
        ltl: antenna.ltl,
        insert_feeds: antenna.insert_feeds,
        list: nil,
        accounts_count: 0,
        domains_count: 0,
        tags_count: 0,
        keywords_count: 0,
      })
    end

    def change_antenna_title
      change { antenna.reload.title }.from('my antenna').to('antenna')
    end

    def change_antenna_ignore_reblog
      change { antenna.reload.ignore_reblog }.from(false).to(true)
    end

    def change_antenna_insert_feeds
      change { antenna.reload.insert_feeds }.from(false).to(true)
    end

    context 'when the antenna does not exist' do
      it 'returns http not found' do
        put '/api/v1/antennas/-1', headers: headers, params: params

        expect(response).to have_http_status(404)
      end
    end

    context 'when the antenna belongs to another user' do
      let(:antenna) { Fabricate(:antenna) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'DELETE /api/v1/antennas/:id' do
    subject do
      delete "/api/v1/antennas/#{antenna.id}", headers: headers
    end

    let(:antenna) { Fabricate(:antenna, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'deletes the antenna', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(Antenna.where(id: antenna.id)).to_not exist
    end

    context 'when the antenna does not exist' do
      it 'returns http not found' do
        delete '/api/v1/antennas/-1', headers: headers

        expect(response).to have_http_status(404)
      end
    end

    context 'when the antenna belongs to another user' do
      let(:antenna) { Fabricate(:antenna) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end
end
