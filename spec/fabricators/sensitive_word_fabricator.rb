# frozen_string_literal: true

Fabricator(:sensitive_word) do
  keyword { sequence(:keyword) { |i| "keyword_#{i}" } }
end
