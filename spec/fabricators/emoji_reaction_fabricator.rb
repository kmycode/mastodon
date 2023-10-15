# frozen_string_literal: true

Fabricator(:emoji_reaction) do
  account { Fabricate.build(:account) }
  status { Fabricate.build(:status) }
  name '😀'
end
