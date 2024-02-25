# frozen_string_literal: true

module NgRuleHelper
  def check_invalid_status_for_ng_rule!(account, **options)
    (check_for_ng_rule!(account, **options) { |rule| !rule.check_status_or_record! }).none?
  end

  def check_invalid_reaction_for_ng_rule!(account, **options)
    (check_for_ng_rule!(account, **options) { |rule| !rule.check_reaction_or_record! }).none?
  end

  private

  def check_for_ng_rule!(account, **options, &block)
    NgRule.cached_rules
          .map { |raw_rule| Admin::NgRule.new(raw_rule, account, **options) }
          .filter(&block)
  end

  def do_account_action_for_rule!(account, action)
    case action
    when :silence
      account.silence!
    when :suspend
      account.suspend!
    end
  end
end
