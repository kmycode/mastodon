# frozen_string_literal: true

class RemoveHiddenAnonymousFromDomainBlocks < ActiveRecord::Migration[7.0]
  class DomainBlock < ApplicationRecord; end

  def up
    safety_assured do
      DomainBlock.where(hidden_anonymous: true, hidden: false).update_all(hidden: true)
      remove_column :domain_blocks, :hidden_anonymous
    end
  end

  def down
    safety_assured do
      add_column :domain_blocks, :hidden_anonymous, :boolean, null: false, default: false
    end
  end
end
