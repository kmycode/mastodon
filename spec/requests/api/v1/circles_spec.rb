# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Circles' do
  let(:user)    { Fabricate(:user) }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:scopes)  { 'read:lists write:lists' }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'GET /api/v1/circles' do
    subject do
      get '/api/v1/circles', headers: headers
    end

    let!(:circles) do
      [
        Fabricate(:circle, account: user.account, title: 'first circle'),
        Fabricate(:circle, account: user.account, title: 'second circle'),
        Fabricate(:circle, account: user.account, title: 'third circle'),
        Fabricate(:circle, account: user.account, title: 'fourth circle'),
      ]
    end

    let(:expected_response) do
      circles.map do |circle|
        {
          id: circle.id.to_s,
          title: circle.title,
        }
      end
    end

    before do
      Fabricate(:circle)
    end

    it_behaves_like 'forbidden for wrong scope', 'write write:lists'

    it 'returns the expected circles', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to match_array(expected_response)
    end
  end

  describe 'GET /api/v1/circles/:id' do
    subject do
      get "/api/v1/circles/#{circle.id}", headers: headers
    end

    let(:circle) { Fabricate(:circle, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'write write:lists'

    it 'returns the requested circle correctly', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to eq({
        id: circle.id.to_s,
        title: circle.title,
      })
    end

    context 'when the circle belongs to a different user' do
      let(:circle) { Fabricate(:circle) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end

    context 'when the circle does not exist' do
      it 'returns http not found' do
        get '/api/v1/circles/-1', headers: headers

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/circles' do
    subject do
      post '/api/v1/circles', headers: headers, params: params
    end

    let(:params) { { title: 'my circle' } }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'returns the new circle', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to match(a_hash_including(title: 'my circle'))
      expect(Circle.where(account: user.account).count).to eq(1)
    end

    context 'when a title is not given' do
      let(:params) { { title: '' } }

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'PUT /api/v1/circles/:id' do
    subject do
      put "/api/v1/circles/#{circle.id}", headers: headers, params: params
    end

    let(:circle)   { Fabricate(:circle, account: user.account, title: 'my circle') }
    let(:params) { { title: 'circle' } }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'returns the updated circle', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      circle.reload

      expect(body_as_json).to eq({
        id: circle.id.to_s,
        title: circle.title,
      })
    end

    it 'updates the circle title' do
      expect { subject }.to change { circle.reload.title }.from('my circle').to('circle')
    end

    context 'when the circle does not exist' do
      it 'returns http not found' do
        put '/api/v1/circles/-1', headers: headers, params: params

        expect(response).to have_http_status(404)
      end
    end

    context 'when the circle belongs to another user' do
      let(:circle) { Fabricate(:circle) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'DELETE /api/v1/circles/:id' do
    subject do
      delete "/api/v1/circles/#{circle.id}", headers: headers
    end

    let(:circle) { Fabricate(:circle, account: user.account) }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    it 'deletes the circle', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(Circle.where(id: circle.id)).to_not exist
    end

    context 'when the circle does not exist' do
      it 'returns http not found' do
        delete '/api/v1/circles/-1', headers: headers

        expect(response).to have_http_status(404)
      end
    end

    context 'when the circle belongs to another user' do
      let(:circle) { Fabricate(:circle) }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end
end
