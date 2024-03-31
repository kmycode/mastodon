# frozen_string_literal: true

class REST::NotificationSerializer < ActiveModel::Serializer
  attributes :id, :type, :created_at

  has_many :statuses, serializer: REST::StatusSerializer, if: :warning_type?

  belongs_to :from_account_web, key: :account, serializer: REST::AccountSerializer
  belongs_to :target_status, key: :status, if: :status_type?, serializer: REST::StatusSerializer
  belongs_to :report, if: :report_type?, serializer: REST::ReportSerializer
  belongs_to :emoji_reaction, if: :emoji_reaction_type?, serializer: REST::NotifyEmojiReactionSerializer
  belongs_to :account_warning, if: :warning_type?, serializer: REST::AccountWarningSerializer
  belongs_to :list, if: :list_status_type?, serializer: REST::ListSerializer
  belongs_to :account_relationship_severance_event, key: :event, if: :relationship_severance_event?, serializer: REST::AccountRelationshipSeveranceEventSerializer

  def id
    object.id.to_s
  end

  def status_type?
    [:favourite, :emoji_reaction, :reaction, :reblog, :status_reference, :status, :list_status, :mention, :poll, :update].include?(object.type)
  end

  def report_type?
    object.type == :'admin.report'
  end

  def warning_type?
    object.type == :warning
  end

  def emoji_reaction_type?
    object.type == :emoji_reaction
  end

  def list_status_type?
    object.type == :list_status
  end

  def list
    object.list_status.list
  end

  def relationship_severance_event?
    object.type == :severed_relationships
  end

  def statuses
    Status.where(id: object.account_warning.status_ids).to_a
  end
end
