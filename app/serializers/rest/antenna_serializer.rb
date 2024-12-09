# frozen_string_literal: true

class REST::AntennaSerializer < ActiveModel::Serializer
  attributes :id, :title, :stl, :ltl, :insert_feeds, :with_media_only, :ignore_reblog, :accounts_count, :domains_count, :tags_count, :keywords_count, :favourite

  class ListSerializer < ActiveModel::Serializer
    attributes :id, :title

    def id
      object.id.to_s
    end
  end

  has_one :list, serializer: ListSerializer, optional: true

  def id
    object.id.to_s
  end

  def accounts_count
    object.antenna_accounts.count
  end

  def domains_count
    object.antenna_domains.count
  end

  def tags_count
    object.antenna_tags.count
  end

  def keywords_count
    object.keywords&.size || 0
  end
end
