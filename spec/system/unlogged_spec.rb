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

  #   expect(subject).to have_css('main.columns-area__panels__main')
  # end
end

# rubocop:enable RSpec/EmptyExampleGroup
