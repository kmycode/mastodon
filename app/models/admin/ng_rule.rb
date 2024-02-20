# frozen_string_literal: true

class Admin::NgRule
  def initialize(ng_rule, account)
    @ng_rule = ng_rule
    @account = account
    @uri = nil
  end

  def account_match_and_record!(uri)
    @uri = uri

    record_if_text_match!(:account_domain, @account.domain, @ng_rule.account_domain) ||
      record_if_text_match!(:account_username, @account.username, @ng_rule.account_username)
  end

  private

  def include?(text, word)
    if word.start_with?('?') && word.size >= 2
      text =~ /#{word[1..]}/i
    else
      text.include?(word)
    end
  end

  def record!(reason, **options)
    NgRuleHistory.create!(ng_rule: @ng_rule, account: @account, reason: reason, uri: @uri, **options)
  end

  def record_if_text_match!(reason, text, arr, **options)
    keyword = detect_keyword(text, arr)

    opts = options.merge({ text: text, keyword: keyword })
    record!(reason, **opts) if keyword.present?
    keyword.present?
  end

  def string_to_array(text)
    text.split("\n")
  end

  def detect_keyword(text, arr)
    arr = string_to_array(arr) if arr.is_a?(String)

    arr.detect { |word| include?(text, word) ? word : nil }
  end

  def detect_keyword?(text, arr)
    detect_keyword(text, arr).present?
  end
end
