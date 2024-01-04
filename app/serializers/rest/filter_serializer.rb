# frozen_string_literal: true

class REST::FilterSerializer < ActiveModel::Serializer
  attributes :id, :title, :exclude_follows, :exclude_localusers, :with_quote, :context, :expires_at, :filter_action, :filter_action_ex
  has_many :keywords, serializer: REST::FilterKeywordSerializer, if: :rules_requested?
  has_many :statuses, serializer: REST::FilterStatusSerializer, if: :rules_requested?

  def id
    object.id.to_s
  end

  def rules_requested?
    instance_options[:rules_requested]
  end

  def filter_action
    return :warn if object.half_warn_action?

    object.filter_action
  end

  def filter_action_ex
    object.filter_action
  end
end
