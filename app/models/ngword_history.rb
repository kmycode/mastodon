# frozen_string_literal: true

# == Schema Information
#
# Table name: ngword_histories
#
#  id          :bigint(8)        not null, primary key
#  uri         :string           not null
#  target_type :integer          not null
#  reason      :integer          not null
#  text        :string           not null
#  keyword     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class NgwordHistory < ApplicationRecord
  include Paginable

  enum target_type: { status: 0, account_note: 1, account_name: 2 }, _suffix: :blocked
  enum reason: { ng_words: 0, ng_words_for_stranger_mention: 1 }, _prefix: :within
end
