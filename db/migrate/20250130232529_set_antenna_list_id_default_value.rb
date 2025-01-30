# frozen_string_literal: true

class SetAntennaListIdDefaultValue < ActiveRecord::Migration[8.0]
  def change
    change_column_default :antennas, :list_id, from: nil, to: 0
  end
end
