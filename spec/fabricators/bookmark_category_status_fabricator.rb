# frozen_string_literal: true

Fabricator(:bookmark_category_status) do
  bookmark_category
  status
  before_create do |_bookmark_category_status, _|
    Bookmark.create!(status: status, account: bookmark_category.account) unless bookmark_category.account.bookmarked?(status)
  end
end
