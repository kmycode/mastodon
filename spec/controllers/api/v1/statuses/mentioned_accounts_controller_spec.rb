# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Statuses::MentionedAccountsController do
  render_views

  let(:user)  { Fabricate(:user) }
  let(:app)   { Fabricate(:application, name: 'Test app', website: 'http://testapp.com') }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application: app, scopes: 'read:accounts') }
  let(:alice) { Fabricate(:account) }
  let(:bob)   { Fabricate(:account) }
  let(:ohagi) { Fabricate(:account) }

  context 'with an oauth token' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token }
    end

    describe 'GET #index' do
      let(:status) { Fabricate(:status, account: user.account) }

      before do
        Mention.create!(account: bob, status: status)
        Mention.create!(account: ohagi, status: status)
      end

      it 'returns http success' do
        get :index, params: { status_id: status.id, limit: 2 }
        expect(response).to have_http_status(200)
        expect(response.headers['Link'].links.size).to eq(2)
      end

      it 'returns accounts who favorited the status' do
        get :index, params: { status_id: status.id, limit: 2 }
        expect(body_as_json.size).to eq 2
        expect([body_as_json[0][:id], body_as_json[1][:id]]).to contain_exactly(bob.id.to_s, ohagi.id.to_s)
      end

      it 'does not return blocked users' do
        user.account.block!(ohagi)
        get :index, params: { status_id: status.id, limit: 2 }
        expect(body_as_json.size).to eq 1
        expect(body_as_json[0][:id]).to eq bob.id.to_s
      end

      context 'when other accounts status' do
        let(:status) { Fabricate(:status, account: alice) }

        it 'returns http unauthorized' do
          get :index, params: { status_id: status.id }
          expect(response).to have_http_status(404)
        end
      end
    end
  end

  context 'without an oauth token' do
    before do
      allow(controller).to receive(:doorkeeper_token).and_return(nil)
    end

    context 'with a public status' do
      let(:status) { Fabricate(:status, account: user.account, visibility: :public) }

      describe 'GET #index' do
        before do
          Mention.create!(account: bob, status: status)
        end

        it 'returns http unauthorized' do
          get :index, params: { status_id: status.id }
          expect(response).to have_http_status(404)
        end
      end
    end
  end
end
