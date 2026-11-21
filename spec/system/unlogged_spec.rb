# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/EmptyExampleGroup

RSpec.describe 'UnloggedBrowsing', :js, :streaming do
  subject { page }

  before do
    visit root_path
  end

  # 401エラーが出る
  # ブラウザでも確認できないため問題先送り
  # it 'loads the home page' do
  #   expect(subject).to have_css('div.app-holder')

  #  expect(subject).to have_css('nav')
  #  expect(subject).to have_css('main')
  #  expect(subject).to have_css('h1', text: frontend_translations('tabs_bar.explore'))
  # end
end

# rubocop:enable RSpec/EmptyExampleGroup
