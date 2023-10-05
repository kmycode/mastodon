# frozen_string_literal: true

Fabricator(:friend_domain) do
  domain 'example.com'
  inbox_url 'https://example.com/inbox'
  active_state :idle
  passive_state :idle
end
