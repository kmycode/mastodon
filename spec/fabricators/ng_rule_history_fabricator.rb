# frozen_string_literal: true

Fabricator(:ng_rule_history) do
  ng_rule { Fabricate.build(:ng_rule) }
  account { Fabricate.build(:account) }
  reason :none
end
