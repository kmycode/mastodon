# frozen_string_literal: true

Fabricator(:pending_status) do
  account { Fabricate.build(:account) }
  fetch_account { Fabricate.build(:account) }
  uri { "https://example.com/#{Time.now.utc.nsec}" }
end
