# frozen_string_literal: true

class CreateSpecifiedDomains < ActiveRecord::Migration[7.1]
  class Setting < ApplicationRecord
    def value
      YAML.safe_load(self[:value], permitted_classes: [ActiveSupport::HashWithIndifferentAccess, Symbol]) if self[:value].present?
    end

    def value=(new_value)
      self[:value] = new_value.to_yaml
    end
  end

  class SpecifiedDomain < ApplicationRecord; end

  def up
    create_table :specified_domains do |t|
      t.string :domain, null: false
      t.integer :table, default: 0, null: false
      t.jsonb :options, null: false, default: {}

      t.timestamps
    end

    add_index :specified_domains, %i(domain table), unique: true

    setting = Setting.find_by(var: :permit_new_account_domains)

    (setting&.value || []).compact.uniq.each do |domain|
      SpecifiedDomain.create!(domain: domain, table: 0)
    end
    setting&.destroy
  end

  def down
    Setting.find_by(var: :permit_new_account_domains)&.destroy
    Setting.new(var: :permit_new_account_domains).tap { |s| s.value = SpecifiedDomain.where(table: 0).pluck(:domain) }.save!

    drop_table :specified_domains
  end
end
