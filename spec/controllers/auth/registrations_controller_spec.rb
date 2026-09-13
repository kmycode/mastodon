# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RegistrationsController do
  render_views

  shared_examples 'registration mode based responses' do |path|
    context 'when in single user mode and open for registration' do
      before do
        Setting.registrations_mode = 'open'
        allow(Rails.configuration.x).to receive(:single_user_mode).and_return(true)
      end

      it 'redirects to sign-in' do
        Fabricate(:account)
        get path

        expect(response).to redirect_to '/auth/sign_in'
        expect(Rails.configuration.x).to have_received(:single_user_mode)
      end
    end

    context 'when registrations closed and not in single user mode' do
      before do
        Setting.registrations_mode = 'none'
        allow(Rails.configuration.x).to receive(:single_user_mode).and_return(false)
      end

      it 'redirects to sign-in' do
        get path

        expect(response).to redirect_to '/auth/sign_in'
        expect(Rails.configuration.x).to have_received(:single_user_mode)
      end
    end
  end

  describe 'GET #edit' do
    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in(Fabricate(:user))
      get :edit
    end

    it 'returns http success and cache headers' do
      expect(response)
        .to have_http_status(200)

      expect(response.headers['Cache-Control'])
        .to include('private, no-store')
    end
  end

  describe 'PUT #update' do
    let(:current_password) { 'current password' }
    let(:user) { Fabricate(:user, password: current_password) }

    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in(user, scope: :user)
    end

    it 'returns http success and cache headers' do
      put :update

      expect(response)
        .to have_http_status(200)
      expect(response.headers['Cache-Control'])
        .to include('private, no-store')
    end

    it 'can update the user email' do
      expect do
        put :update, params: {
          user: {
            email: 'newemail@example.com',
            current_password: current_password,
          },
        }
        expect(response).to redirect_to(edit_user_registration_path)
      end.to change { user.reload.unconfirmed_email }.to('newemail@example.com')
    end

    it 'requires the current password to update the email' do
      expect do
        put :update, params: {
          user: {
            email: 'newemail@example.com',
            current_password: 'something',
          },
        }
        expect(response).to have_http_status(200)
      end.to_not(change { user.reload.unconfirmed_email })
    end

    it 'can update the user password' do
      expect do
        put :update, params: {
          user: {
            password: 'new password',
            password_confirmation: 'new password',
            current_password: current_password,
          },
        }
        expect(response).to redirect_to(edit_user_registration_path)
      end.to(change { user.reload.encrypted_password })
    end

    it 'requires the password confirmation' do
      expect do
        put :update, params: {
          user: {
            password: 'new password',
            password_confirmation: 'something else',
            current_password: current_password,
          },
        }
        expect(response).to have_http_status(200)
      end.to_not(change { user.reload.encrypted_password })
    end

    it 'requires the current password to update the password' do
      expect do
        put :update, params: {
          user: {
            password: 'new password',
            password_confirmation: 'new password',
            current_password: 'something',
          },
        }
        expect(response).to have_http_status(200)
      end.to_not(change { user.reload.encrypted_password })
    end

    context 'when suspended' do
      let(:user) { Fabricate(:user, account_attributes: { username: 'test', suspended_at: Time.now.utc }) }

      it 'returns http forbidden' do
        put :update
        expect(response).to have_http_status(403)
      end
    end

    context 'when deleted' do
      let(:user) { Fabricate(:user, account_attributes: { username: 'test', requested_deletion_at: Time.now.utc }) }

      it 'returns http forbidden' do
        put :update
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET #new' do
    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
    end

    context 'with open registrations' do
      it 'returns http success' do
        Setting.registrations_mode = 'open'
        get :new
        expect(response).to have_http_status(200)
      end
    end

    it_behaves_like 'registration mode based responses', :new
  end

  describe 'POST #create' do
    let(:accept_language) { 'de' }

    before do
      session[:registration_form_time] = 5.seconds.ago

      request.env['devise.mapping'] = Devise.mappings[:user]
    end

    around do |example|
      I18n.with_locale(I18n.locale) do
        example.run
      end
    end

    context 'when an accept language is present in headers' do
      subject do
        Setting.registrations_mode = 'open'
        request.headers['Accept-Language'] = accept_language
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      it 'redirects to setup and creates user' do
        subject

        expect(response)
          .to redirect_to auth_setup_path
        expect(User.find_by(email: 'test@example.com'))
          .to be_present
          .and have_attributes(locale: eq(accept_language))
      end
    end

    context 'when user has not agreed to terms of service' do
      subject do
        Setting.registrations_mode = 'open'
        request.headers['Accept-Language'] = accept_language
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'false' } }
      end

      it 'does not create user' do
        subject
        user = User.find_by(email: 'test@example.com')
        expect(user).to be_nil
      end
    end

    context 'when user has an email address requiring approval' do
      subject do
        request.headers['Accept-Language'] = accept_language
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      before do
        Setting.registrations_mode = 'open'
        Fabricate(:email_domain_block, allow_with_approval: true, domain: 'example.com')
      end

      it 'creates unapproved user and redirects to setup' do
        subject
        expect(response).to redirect_to auth_setup_path

        user = User.find_by(email: 'test@example.com')
        expect(user).to_not be_nil
        expect(user.locale).to eq(accept_language)
        expect(user.approved).to be(false)
      end
    end

    context 'when user has an email address requiring approval through a MX record' do
      subject do
        request.headers['Accept-Language'] = accept_language
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      before do
        Setting.registrations_mode = 'open'
        Fabricate(:email_domain_block, allow_with_approval: true, domain: 'mail.example.com')
        allow(User).to receive(:skip_mx_check?).and_return(false)
        configure_mx(domain: 'example.com', exchange: 'mail.example.com')
      end

      it 'creates unapproved user and redirects to setup' do
        subject
        expect(response).to redirect_to auth_setup_path

        user = User.find_by(email: 'test@example.com')
        expect(user).to_not be_nil
        expect(user.locale).to eq(accept_language)
        expect(user.approved).to be(false)
      end
    end

    context 'with an already taken username' do
      subject do
        Setting.registrations_mode = 'open'
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      before do
        Fabricate(:account, username: 'test')
      end

      it 'responds with an error message about the username' do
        subject

        expect(response).to have_http_status(:success)
        expect(username_error_text).to eq(I18n.t('errors.messages.taken'))
      end

      def username_error_text
        response.parsed_body.css('.user_account_username .error').text
      end
    end

    context 'when max user count is set' do
      subject do
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      let(:users_max) { 3 }

      before do
        Fabricate(:user)
        Fabricate(:user)
        Setting.registrations_mode = 'open'
        Setting.registrations_limit = users_max
        request.headers['Accept-Language'] = accept_language
      end

      it 'redirects to setup' do
        subject
        expect(response).to redirect_to auth_setup_path
      end

      it 'creates user' do
        subject
        user = User.find_by(email: 'test@example.com')
        expect(user).to_not be_nil
        expect(user.locale).to eq(accept_language)
      end

      context 'when limit is reached' do
        let(:users_max) { 2 }

        it 'does not create user' do
          subject
          user = User.find_by(email: 'test@example.com')
          expect(user).to be_nil
        end

        context 'with invite' do
          subject do
            post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', invite_code: invite.code, agreement: 'true' } }
          end

          let(:invite) { Fabricate(:invite) }

          it 'creates user' do
            subject
            user = User.find_by(email: 'test@example.com')
            expect(user).to_not be_nil
            expect(user.locale).to eq(accept_language)
          end
        end
      end
    end

    context 'when max user count per day is set' do
      subject do
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      let(:users_max) { 2 }
      let(:created_at) { Time.now.utc }
      let(:precreate_users) { true }

      before do
        Fabricate(:user, created_at: created_at) if precreate_users
        Setting.registrations_mode = 'open'
        Setting.registrations_limit_per_day = users_max
        request.headers['Accept-Language'] = accept_language
      end

      it 'creates user' do
        subject
        user = User.find_by(email: 'test@example.com')
        expect(user).to_not be_nil
        expect(user.locale).to eq(accept_language)
      end

      context 'when limit is reached' do
        let(:users_max) { 2 }
        let(:created_at) { Time.now.utc - 1.day }
        let(:precreate_users) { false }

        before do
          travel_to Time.now.utc - 1.day
          Fabricate(:user)
          create_other_user
        end

        it 'does not create user yesterday' do
          subject
          user = User.find_by(email: 'test@example.com')
          expect(user).to be_nil
        end

        it 'creates user' do
          travel_to Time.now.utc + 1.day
          subject
          user = User.find_by(email: 'test@example.com')
          expect(user).to_not be_nil
          expect(user.locale).to eq(accept_language)
        end
      end

      def create_other_user
        post :create, params: { user: { account_attributes: { username: 'ohagi' }, email: 'test@ohagi.com', password: 'ohagi_must_be_tsubuan', password_confirmation: 'ohagi_must_be_tsubuan', agreement: 'true' } }
      end
    end

    context 'when registration time range is set' do
      subject do
        post :create, params: { user: { account_attributes: { username: 'test' }, email: 'test@example.com', password: '12345678', password_confirmation: '12345678', agreement: 'true' } }
      end

      shared_examples 'registration with time' do |header, start_hour_val, end_hour_val, secondary_start_hour_val, secondary_end_hour_val, result|
        context header do
          let(:start_hour) { start_hour_val }
          let(:end_hour) { end_hour_val }
          let(:secondary_start_hour) { secondary_start_hour_val }
          let(:secondary_end_hour) { secondary_end_hour_val }

          before do
            Setting.registrations_mode = 'open'
            Setting.registrations_start_hour = start_hour
            Setting.registrations_end_hour = end_hour
            Setting.registrations_secondary_start_hour = secondary_start_hour
            Setting.registrations_secondary_end_hour = secondary_end_hour
            request.headers['Accept-Language'] = accept_language

            current = Time.now.utc
            today = current.beginning_of_day
            today += 1.day if current.hour >= 10
            travel_to today + 10.hours
          end

          if result
            it 'creates user' do
              subject
              user = User.find_by(email: 'test@example.com')
              expect(user).to_not be_nil
              expect(user.locale).to eq(accept_language)
              expect(user.approved?).to be true
            end
          else
            it 'does not create user' do
              subject
              user = User.find_by(email: 'test@example.com')
              expect(user).to_not be_nil
              expect(user.approved?).to be false
            end
          end
        end
      end

      it_behaves_like 'registration with time', 'time range is not set', 0, 24, 0, 0, true
      it_behaves_like 'registration with time', 'time range is default values', 0, 0, 0, 0, true
      it_behaves_like 'registration with time', 'time range is set', 9, 12, 0, 0, true
      it_behaves_like 'registration with time', 'time range is out of range', 12, 15, 0, 0, false
      it_behaves_like 'registration with time', 'time range is invalid', 20, 15, 0, 0, true
      it_behaves_like 'registration with time', 'secondary time range is set', 0, 4, 9, 12, true
      it_behaves_like 'registration with time', 'secondary time range is out of range', 0, 4, 12, 15, false
      it_behaves_like 'registration with time', 'secondary time range is invalid', 0, 4, 20, 15, false
      it_behaves_like 'registration with time', 'both time range are invalid', 4, 0, 20, 15, true
      it_behaves_like 'registration with time', 'only secondary time range is set', 0, 0, 9, 12, true
    end

    it_behaves_like 'registration mode based responses', :create
  end

  describe 'DELETE #destroy' do
    let(:user) { Fabricate(:user) }

    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in(user, scope: :user)
      delete :destroy
    end

    it 'returns http not found and keeps user' do
      expect(response)
        .to have_http_status(404)
      expect(User.find(user.id))
        .to_not be_nil
    end
  end
end
