# frozen_string_literal: true

Fabricator(:friend_domain) do
  domain 'example.com'
  inbox_url 'https://example.com/inbox'
  active_state :idle
  passive_state :idle
  available true
  before_create { |friend_domain, _| friend_domain.inbox_url = "https://#{friend_domain.domain}/inbox" if friend_domain.inbox_url.blank? }
end
