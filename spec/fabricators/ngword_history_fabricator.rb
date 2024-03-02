# frozen_string_literal: true

Fabricator(:ngword_history) do
  uri 'https://test.com/'
  target_type 0
  reason 0
  text 'this is an invalid text'
  keyword 'invalid'
end
