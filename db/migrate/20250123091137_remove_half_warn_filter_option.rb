# frozen_string_literal: true

class RemoveHalfWarnFilterOption < ActiveRecord::Migration[8.0]
  class CustomFilter < ApplicationRecord; end

  def up
    CustomFilter.where(action: 2).in_batches.update_all(action: 0)
  end

  def down; end
end
