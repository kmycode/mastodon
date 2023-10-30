# frozen_string_literal: true

Fabricator(:list_status) do
  list { Fabricate.build(:list) }
  status
end
