# frozen_string_literal: true

class REST::ListSerializer < ActiveModel::Serializer
  attributes :id, :title, :replies_policy, :exclusive, :notify

  def id
    object.id.to_s
  end

  class AntennaSerializer < ActiveModel::Serializer
    attributes :id, :title, :stl

    def id
      object.id.to_s
    end
  end

  has_many :antennas, serializer: AntennaSerializer

  def antennas
    object.antennas.where(insert_feeds: true)
  end
end
