# frozen_string_literal: true

Fabricator(:ng_rule) do
  status_visibility %w(public)
  status_searchability %w(direct unset)
  reaction_type %w(favourite)
end
