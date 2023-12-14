# frozen_string_literal: true

require 'rails_helper'

describe '/api/v1/statuses' do
  context 'with an oauth token' do
    let(:user)  { Fabricate(:user) }
    let(:client_app) { Fabricate(:application, name: 'Test app', website: 'http://testapp.com') }
    let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: client_app, scopes: scopes) }
    let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

    describe 'GET /api/v1/statuses/:id' do
      subject do
        get "/api/v1/statuses/#{status.id}", headers: headers
      end

      let(:scopes) { 'read:statuses' }
      let(:status) { Fabricate(:status, account: user.account) }

      it_behaves_like 'forbidden for wrong scope', 'write write:statuses'

      it 'returns http success' do
        subject

        expect(response).to have_http_status(200)
      end

      context 'when post includes filtered terms' do
        let(:status) { Fabricate(:status, text: 'this toot is about that banned word') }

        before do
          user.account.custom_filters.create!(phrase: 'filter1', context: %w(home), action: :hide, keywords_attributes: [{ keyword: 'banned' }, { keyword: 'irrelevant' }])
        end

        it 'returns filter information', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(body_as_json[:filtered][0]).to include({
            filter: a_hash_including({
              id: user.account.custom_filters.first.id.to_s,
              title: 'filter1',
              filter_action: 'hide',
            }),
            keyword_matches: ['banned'],
          })
        end
      end

      context 'when post is explicitly filtered' do
        let(:status) { Fabricate(:status, text: 'hello world') }

        before do
          filter = user.account.custom_filters.create!(phrase: 'filter1', context: %w(home), action: :hide)
          filter.statuses.create!(status_id: status.id)
        end

        it 'returns filter information', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(body_as_json[:filtered][0]).to include({
            filter: a_hash_including({
              id: user.account.custom_filters.first.id.to_s,
              title: 'filter1',
              filter_action: 'hide',
            }),
            status_matches: [status.id.to_s],
          })
        end
      end

      context 'when reblog includes filtered terms' do
        let(:status) { Fabricate(:status, reblog: Fabricate(:status, text: 'this toot is about that banned word')) }

        before do
          user.account.custom_filters.create!(phrase: 'filter1', context: %w(home), action: :hide, keywords_attributes: [{ keyword: 'banned' }, { keyword: 'irrelevant' }])
        end

        it 'returns filter information', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(body_as_json[:reblog][:filtered][0]).to include({
            filter: a_hash_including({
              id: user.account.custom_filters.first.id.to_s,
              title: 'filter1',
              filter_action: 'hide',
            }),
            keyword_matches: ['banned'],
          })
        end
      end
    end

    describe 'GET /api/v1/statuses/:id/context' do
      let(:scopes) { 'read:statuses' }
      let(:status) { Fabricate(:status, account: user.account) }
      let!(:thread) { Fabricate(:status, account: user.account, thread: status) }

      it 'returns http success' do
        get "/api/v1/statuses/#{status.id}/context", params: { id: status.id }
        expect(response).to have_http_status(200)
      end

      context 'when has also reference' do
        before do
          Fabricate(:status_reference, status: thread, target_status: status)
        end

        it 'returns unique ancestors' do
          get "/api/v1/statuses/#{thread.id}/context"
          status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }

          expect(status_ids).to eq [status.id]
        end

        it 'returns unique references' do
          get "/api/v1/statuses/#{thread.id}/context", params: { with_reference: true }
          ancestor_status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }
          reference_status_ids = body_as_json[:references].map { |ref| ref[:id].to_i }

          expect(ancestor_status_ids).to eq [status.id]
          expect(reference_status_ids).to eq []
        end
      end
    end

    context 'with reference' do
      let(:status) { Fabricate(:status, account: user.account) }
      let(:scopes) { 'read:statuses' }
      let(:referred) { Fabricate(:status) }
      let(:referred_private) { Fabricate(:status, visibility: :private) }
      let(:referred_private_following) { Fabricate(:status, visibility: :private) }

      before do
        user.account.follow!(referred_private_following.account)
        Fabricate(:status_reference, status: status, target_status: referred)
        Fabricate(:status_reference, status: status, target_status: referred_private)
        Fabricate(:status_reference, status: status, target_status: referred_private_following)
      end

      it 'returns http success' do
        get "/api/v1/statuses/#{status.id}/context", headers: headers

        expect(response).to have_http_status(200)
      end

      it 'returns empty references' do
        get "/api/v1/statuses/#{status.id}/context", headers: headers
        status_ids = body_as_json[:references].map { |ref| ref[:id].to_i }

        expect(status_ids).to eq []
      end

      it 'contains referred status' do
        get "/api/v1/statuses/#{status.id}/context", headers: headers
        status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }

        expect(status_ids).to include referred.id
        expect(status_ids).to include referred_private_following.id
      end

      it 'does not contain private status' do
        get "/api/v1/statuses/#{status.id}/context", headers: headers
        status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }

        expect(status_ids).to_not include referred_private.id
      end

      it 'does not contain private status when not autienticated' do
        get "/api/v1/statuses/#{status.id}/context"
        status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }

        expect(status_ids).to_not include referred_private.id
      end

      context 'when with_reference is enabled' do
        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context", params: { with_reference: true }, headers: headers
          expect(response).to have_http_status(200)
        end

        it 'returns empty ancestors' do
          get "/api/v1/statuses/#{status.id}/context", params: { with_reference: true }, headers: headers
          status_ids = body_as_json[:ancestors].map { |ref| ref[:id].to_i }

          expect(status_ids).to eq []
        end

        it 'contains referred status' do
          get "/api/v1/statuses/#{status.id}/context", params: { with_reference: true }, headers: headers
          status_ids = body_as_json[:references].map { |ref| ref[:id].to_i }

          expect(status_ids).to include referred.id
        end
      end
    end

    describe 'POST /api/v1/statuses' do
      subject do
        post '/api/v1/statuses', headers: headers, params: params
      end

      let(:scopes) { 'write:statuses' }
      let(:params) { { status: 'Hello world' } }

      it_behaves_like 'forbidden for wrong scope', 'read read:statuses'

      context 'with a basic status body' do
        it 'returns rate limit headers', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(response.headers['X-RateLimit-Limit']).to eq RateLimiter::FAMILIES[:statuses][:limit].to_s
          expect(response.headers['X-RateLimit-Remaining']).to eq (RateLimiter::FAMILIES[:statuses][:limit] - 1).to_s
        end
      end

      context 'with a safeguard' do
        let!(:alice) { Fabricate(:account, username: 'alice') }
        let!(:bob)   { Fabricate(:account, username: 'bob') }

        let(:params) { { status: '@alice hm, @bob is really annoying lately', allowed_mentions: [alice.id] } }

        it 'returns serialized extra accounts in body', :aggregate_failures do
          subject

          expect(response).to have_http_status(422)
          expect(body_as_json[:unexpected_accounts].map { |a| a.slice(:id, :acct) }).to eq [{ id: bob.id.to_s, acct: bob.acct }]
        end
      end

      context 'with missing parameters' do
        let(:params) { {} }

        it 'returns rate limit headers', :aggregate_failures do
          subject

          expect(response).to have_http_status(422)
          expect(response.headers['X-RateLimit-Limit']).to eq RateLimiter::FAMILIES[:statuses][:limit].to_s
        end
      end

      context 'when exceeding rate limit' do
        before do
          rate_limiter = RateLimiter.new(user.account, family: :statuses)
          RateLimiter::FAMILIES[:statuses][:limit].times { rate_limiter.record! }
        end

        it 'returns rate limit headers', :aggregate_failures do
          subject

          expect(response).to have_http_status(429)
          expect(response.headers['X-RateLimit-Limit']).to eq RateLimiter::FAMILIES[:statuses][:limit].to_s
          expect(response.headers['X-RateLimit-Remaining']).to eq '0'
        end
      end
    end

    describe 'DELETE /api/v1/statuses/:id' do
      subject do
        delete "/api/v1/statuses/#{status.id}", headers: headers
      end

      let(:scopes) { 'write:statuses' }
      let(:status) { Fabricate(:status, account: user.account) }

      it_behaves_like 'forbidden for wrong scope', 'read read:statuses'

      it 'removes the status', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(Status.find_by(id: status.id)).to be_nil
      end
    end

    describe 'PUT /api/v1/statuses/:id' do
      subject do
        put "/api/v1/statuses/#{status.id}", headers: headers, params: { status: 'I am updated' }
      end

      let(:scopes) { 'write:statuses' }
      let(:status) { Fabricate(:status, account: user.account) }

      it_behaves_like 'forbidden for wrong scope', 'read read:statuses'

      it 'updates the status', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(status.reload.text).to eq 'I am updated'
      end
    end
  end

  context 'without an oauth token' do
    context 'with a private status' do
      let(:status) { Fabricate(:status, visibility: :private) }

      describe 'GET /api/v1/statuses/:id' do
        it 'returns http unauthorized' do
          get "/api/v1/statuses/#{status.id}"

          expect(response).to have_http_status(404)
        end
      end

      describe 'GET /api/v1/statuses/:id/context' do
        before do
          Fabricate(:status, thread: status)
        end

        it 'returns http unauthorized' do
          get "/api/v1/statuses/#{status.id}/context"

          expect(response).to have_http_status(404)
        end
      end
    end

    context 'with a public status' do
      let(:status) { Fabricate(:status, visibility: :public) }

      describe 'GET /api/v1/statuses/:id' do
        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}"

          expect(response).to have_http_status(200)
        end
      end

      describe 'GET /api/v1/statuses/:id/context' do
        before do
          Fabricate(:status, thread: status)
        end

        it 'returns http success' do
          get "/api/v1/statuses/#{status.id}/context"

          expect(response).to have_http_status(200)
        end
      end
    end
  end
end
