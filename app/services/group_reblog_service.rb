# frozen_string_literal: true

class GroupReblogService < BaseService
  def call(status)
    return nil if status.account.group?

    visibility = status.visibility.to_sym
    return nil unless %i(public public_unlisted unlisted login).include?(visibility)

    status.mentions.map(&:account).each do |account|
      next unless account.local?
      next unless status.account.following?(account)
      next unless account.group?
      next if account.id == status.account_id

      ReblogService.new.call(account, status, { visibility: status.visibility })
    end
  end
end
