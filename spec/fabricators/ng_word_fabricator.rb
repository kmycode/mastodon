# frozen_string_literal: true

Fabricator(:ng_word) do
  keyword { sequence(:keyword) { |i| "keyword_#{i}" } }
end
