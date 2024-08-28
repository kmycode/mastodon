# frozen_string_literal: true

require 'rails_helper'

describe 'User custom CSS' do
  let(:user)       { Fabricate(:user) }
  let(:custom_css) { '* { display: none !important; }' }

  describe 'GET /user_custom.css' do
    context 'without sign in' do
      it 'returns 422' do
        get '/user_custom.css'

        expect(response).to have_http_status(401)
      end
    end

    context 'with sign in but custom css is not enabled' do
      before do
        user.update!(custom_css_text: custom_css)
        sign_in user
      end

      it 'returns custom css' do
        get '/user_custom.css'

        expect(response).to have_http_status(200)
        expect(response.content_type).to include 'text/css'
        expect(response.body.strip).to eq custom_css
      end
    end

    context 'with sign in and custom css is enabled' do
      before do
        user.update!(custom_css_text: custom_css, settings: { 'web.use_custom_css': true })
        sign_in user
      end

      it 'returns custom css' do
        get '/user_custom.css'

        expect(response).to have_http_status(200)
        expect(response.content_type).to include 'text/css'
        expect(response.body.strip).to eq custom_css
      end
    end
  end
end
