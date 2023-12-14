# frozen_string_literal: true

Fabricator(:bookmark_category) do
  account { Fabricate.build(:account) }
  title 'MyString'
end
