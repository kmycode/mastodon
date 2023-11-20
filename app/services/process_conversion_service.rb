# frozen_string_literal: true

class ProcessConversionService < BaseService
  def call(status)
    @status = status

    return if !@status.limited_visibility? || @status.conversation.nil?

    duplicate_reply!
  end

  private

  def thread
    @thread ||= @status.thread || @status.conversation.ancestor_status
  end

  def duplicate_reply!
    return unless @status.conversation.local?
    return if !@status.reply? || thread.nil?
    return if thread.conversation_id != @status.conversation_id

    mentioned_account_ids = @status.mentions.pluck(:account_id)

    thread.mentioned_accounts.find_each do |account|
      @status.mentions << @status.mentions.new(silent: true, account: account) unless mentioned_account_ids.include?(account.id)
      mentioned_account_ids << account.id
    end
    @status.mentions << @status.mentions.new(silent: true, account: thread.account) unless mentioned_account_ids.include?(thread.account.id)

    @status.save!
  end
end
