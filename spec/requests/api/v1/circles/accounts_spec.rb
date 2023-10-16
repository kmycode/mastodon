# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts' do
  let(:user)    { Fabricate(:user) }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:scopes)  { 'read:lists write:lists' }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'GET /api/v1/circles/:id/accounts' do
    subject do
      get "/api/v1/circles/#{circle.id}/accounts", headers: headers, params: params
    end

    let(:params)   { { limit: 0 } }
    let(:circle)   { Fabricate(:circle, account: user.account) }
    let(:accounts) { Fabricate.times(3, :account) }

    let(:expected_response) do
      accounts.map do |account|
        a_hash_including(id: account.id.to_s, username: account.username, acct: account.acct)
      end
    end

    before do
      accounts.each { |account| account.follow!(user.account) }
      circle.accounts << accounts
    end

    it_behaves_like 'forbidden for wrong scope', 'write write:lists'

    it 'returns the accounts in the requested circle', :aggregate_failures do
      subject

      expect(response).to have_http_status(200)
      expect(body_as_json).to match_array(expected_response)
    end

    context 'with limit param' do
      let(:params) { { limit: 1 } }

      it 'returns only the requested number of accounts' do
        subject

        expect(body_as_json.size).to eq(params[:limit])
      end
    end
  end

  describe 'POST /api/v1/circles/:id/accounts' do
    subject do
      post "/api/v1/circles/#{circle.id}/accounts", headers: headers, params: params
    end

    let(:circle) { Fabricate(:circle, account: user.account) }
    let(:bob)    { Fabricate(:account, username: 'bob') }
    let(:params) { { account_ids: [bob.id] } }

    it_behaves_like 'forbidden for wrong scope', 'read read:lists'

    context 'when the added account is followed' do
      before do
        bob.follow!(user.account)
      end

      it 'adds account to the circle', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(circle.accounts).to include(bob)
      end
    end

    context 'when the added account is not followed' do
      it 'does not add the account to the circle', :aggregate_failures do
        subject

        expect(response).to have_http_status(404)
        expect(circle.accounts).to_not include(bob)
      end
    end

    context 'when the circle is not owned by the requesting user' do
      let(:circle) { Fabricate(:circle) }

      before do
        bob.follow!(user.account)
      end

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end

    context 'when account is already in the circle' do
      before do
        bob.follow!(user.account)
        circle.accounts << bob
      end

      it 'returns http unprocessable entity' do
        subject

        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'DELETE /api/v1/circles/:id/accounts' do
    subject do
      delete "/api/v1/circles/#{circle.id}/accounts", headers: headers, params: params
    end

    context 'when the circle is owned by the requesting user' do
      let(:circle) { Fabricate(:circle, account: user.account) }
      let(:bob)    { Fabricate(:account, username: 'bob') }
      let(:peter)  { Fabricate(:account, username: 'peter') }
      let(:params) { { account_ids: [bob.id] } }

      before do
        bob.follow!(user.account)
        peter.follow!(user.account)
        circle.accounts << [bob, peter]
      end

      it 'removes the specified account from the circle', :aggregate_failures do
        subject

        expect(response).to have_http_status(200)
        expect(circle.accounts).to_not include(bob)
      end

      it 'does not remove any other account from the circle' do
        subject

        expect(circle.accounts).to include(peter)
      end

      context 'when the specified account is not in the circle' do
        let(:params) { { account_ids: [0] } }

        it 'does not remove any account from the circle', :aggregate_failures do
          subject

          expect(response).to have_http_status(200)
          expect(circle.accounts).to contain_exactly(bob, peter)
        end
      end
    end

    context 'when the circle is not owned by the requesting user' do
      let(:circle) { Fabricate(:circle) }
      let(:params) { {} }

      it 'returns http not found' do
        subject

        expect(response).to have_http_status(404)
      end
    end
  end
end
