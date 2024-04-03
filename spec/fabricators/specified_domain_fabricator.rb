# frozen_string_literal: true

Fabricator(:specified_domain) do
  domain { sequence(:domain) { |i| "example_#{i}.com" } }
end
