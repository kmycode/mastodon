# frozen_string_literal: true

module NgRuleHelper
  def check_invalid_status_for_ng_rule!(account, **options)
    (check_for_ng_rule!(account, **options) { |rule| !rule.check_status_or_record! }).none? { |rule| rule.account_action == :suspend || rule.status_action == :reject }
  end

  def check_invalid_reaction_for_ng_rule!(account, **options)
    (check_for_ng_rule!(account, **options) { |rule| !rule.check_reaction_or_record! }).none? { |rule| rule.account_action == :suspend || rule.reaction_action == :reject }
  end

  private

  def check_for_ng_rule!(account, **options, &block)
    NgRule.cached_rules
          .map { |raw_rule| Admin::NgRule.new(raw_rule, account, **options) }
          .filter(&block)
          .tap do |rules|
      account_actions = rules.map(&:account_action).uniq
      if account_actions.include? :suspend
        do_account_action_for_rule!(account, :suspend)
      elsif account_actions.include? :silence
        do_account_action_for_rule!(account, :silence)
      end
    end
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
