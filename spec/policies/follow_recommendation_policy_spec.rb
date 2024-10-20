# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FollowRecommendationPolicy do
  let(:policy) { described_class }
  let(:admin)   { Fabricate(:user, role: UserRole.find_by(name: 'Admin')).account }
  let(:john)    { Fabricate(:account) }

  permissions :show?, :suppress?, :unsuppress? do
    context 'with an admin' do
      it 'permits' do
        expect(policy).to permit(admin, FollowRecommendation)
      end
    end

    context 'with a non-admin' do
      it 'denies' do
        expect(policy).to_not permit(john, FollowRecommendation)
      end
    end
  end
end
