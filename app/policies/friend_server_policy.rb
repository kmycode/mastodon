# frozen_string_literal: true

class FriendServerPolicy < ApplicationPolicy
  def update?
    role.can?(:manage_federation)
  end
end
