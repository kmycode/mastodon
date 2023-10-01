# frozen_string_literal: true

Fabricator(:status_reference) do
  status         { Fabricate.build(:status) }
  target_status  { Fabricate.build(:status) }
  attribute_type 'BT'
  quote          false
end
