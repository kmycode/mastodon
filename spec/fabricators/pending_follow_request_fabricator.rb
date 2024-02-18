# frozen_string_literal: true

Fabricator(:pending_follow_request) do
  account { Fabricate.build(:account) }
  target_account { Fabricate.build(:account, locked: true) }
  uri 'https://example.com/follow'
end
