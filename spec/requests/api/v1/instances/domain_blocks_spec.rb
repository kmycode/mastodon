# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Domain Blocks' do
  let(:user)    { Fabricate(:user) }
  let(:token)   { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:scopes)  { 'read' }
  let(:headers) { { Authorization: "Bearer #{token.token}" } }

  describe 'GET /api/v1/instance/domain_blocks' do
    before do
      Fabricate(:domain_block)
    end

    context 'with domain blocks set to all' do
      before { Setting.show_domain_blocks = 'all' }

      it 'returns http success' do
        get api_v1_instance_domain_blocks_path

        expect(response)
          .to have_http_status(200)

        expect(body_as_json)
          .to be_present
          .and(be_an(Array))
          .and(have_attributes(size: 1))
      end

      context 'with hidden domain block' do
        before { Fabricate(:domain_block, domain: 'hello.com', hidden: true) }

        it 'returns http success and dont include hidden record' do
          get api_v1_instance_domain_blocks_path

          expect(body_as_json.pluck(:domain)).to_not include('hello.com')
        end
      end
    end

    context 'with domain blocks set to users' do
      before { Setting.show_domain_blocks = 'users' }

      it 'returns http not found' do
        get api_v1_instance_domain_blocks_path

        expect(response)
          .to have_http_status(404)
      end
    end

    context 'with domain blocks set to users with access token' do
      before { Setting.show_domain_blocks = 'users' }

      it 'returns http not found' do
        get api_v1_instance_domain_blocks_path, headers: headers

        expect(response)
          .to have_http_status(200)

        expect(body_as_json)
          .to be_present
          .and(be_an(Array))
          .and(have_attributes(size: 1))
      end

      context 'with hidden domain block' do
        before { Fabricate(:domain_block, domain: 'hello.com', hidden: true) }

        it 'returns http success and dont include hidden record' do
          get api_v1_instance_domain_blocks_path, headers: headers

          expect(body_as_json.pluck(:domain)).to_not include('hello.com')
        end
      end
    end

    context 'with domain blocks set to disabled' do
      before { Setting.show_domain_blocks = 'disabled' }

      it 'returns http not found' do
        get api_v1_instance_domain_blocks_path

        expect(response)
          .to have_http_status(404)
      end
    end
  end
end
