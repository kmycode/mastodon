# frozen_string_literal: true

Fabricator(:scheduled_expiration_status) do
  account { Fabricate.build(:account) }
  status { Fabricate.build(:status) }
  scheduled_at { 20.hours.from_now }
end
