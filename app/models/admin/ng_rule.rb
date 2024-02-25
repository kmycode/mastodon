# frozen_string_literal: true

class Admin::NgRule
  def initialize(ng_rule, account, **options)
    @ng_rule = ng_rule
    @account = account
    @options = options
    @uri = nil
  end

  def account_match?
    return false if @account.local? && !@ng_rule.account_include_local
    return false if !@account.local? && @ng_rule.account_allow_followed_by_local && followed_by_local_accounts?

    if @account.local?
      return false unless @ng_rule.account_include_local
    else
      return false unless text_match?(:account_domain, @account.domain, @ng_rule.account_domain)
    end

    text_match?(:account_username, @account.username, @ng_rule.account_username) &&
      text_match?(:account_display_name, @account.display_name, @ng_rule.account_display_name) &&
      text_match?(:account_note, @account.note, @ng_rule.account_note) &&
      text_match?(:account_field_name, @account.fields&.map(&:name)&.join("\n"), @ng_rule.account_field_name) &&
      text_match?(:account_field_value, @account.fields&.map(&:value)&.join("\n"), @ng_rule.account_field_value) &&
      media_state_match?(:account_avatar_state, @account.avatar, @ng_rule.account_avatar_state) &&
      media_state_match?(:account_header_state, @account.header, @ng_rule.account_header_state)
  end

  def status_match? # rubocop:disable Metrics/CyclomaticComplexity
    return false if @ng_rule.status_allow_follower_mention && @options[:mention_to_following]

    has_media = @options[:media_count].is_a?(Integer) && @options[:media_count].positive?
    has_poll = @options[:poll_count].is_a?(Integer) && @options[:poll_count].positive?
    has_mention = @options[:mention_count].is_a?(Integer) && @options[:mention_count].positive?
    has_reference = @options[:reference_count].is_a?(Integer) && @options[:reference_count].positive?

    @options = @options.merge({ searchability: 'unset' }) if @options[:searchability].nil?

    text_match?(:status_spoiler_text, @options[:spoiler_text], @ng_rule.status_spoiler_text) &&
      text_match?(:status_text, @options[:text], @ng_rule.status_text) &&
      text_match?(:status_tag, @options[:tag_names]&.join("\n"), @ng_rule.status_tag) &&
      enum_match?(:status_visibility, @options[:visibility], @ng_rule.status_visibility) &&
      enum_match?(:status_searchability, @options[:searchability], @ng_rule.status_searchability) &&
      state_match?(:status_sensitive_state, @options[:sensitive], @ng_rule.status_sensitive_state) &&
      state_match?(:status_cw_state, @options[:spoiler_text].present?, @ng_rule.status_cw_state) &&
      state_match?(:status_media_state, has_media, @ng_rule.status_media_state) &&
      state_match?(:status_poll_state, has_poll, @ng_rule.status_poll_state) &&
      state_match?(:status_quote_state, @options[:quote], @ng_rule.status_quote_state) &&
      state_match?(:status_reply_state, @options[:reply], @ng_rule.status_reply_state) &&
      state_match?(:status_mention_state, has_mention, @ng_rule.status_mention_state) &&
      state_match?(:status_reference_state, has_reference, @ng_rule.status_reference_state) &&
      value_over_threshold?(:status_tag_threshold, (@options[:tag_names] || []).size, @ng_rule.status_tag_threshold) &&
      value_over_threshold?(:status_media_threshold, @options[:media_count], @ng_rule.status_media_threshold) &&
      value_over_threshold?(:status_poll_threshold, @options[:poll_count], @ng_rule.status_poll_threshold) &&
      value_over_threshold?(:status_mention_threshold, @options[:mention_count], @ng_rule.status_mention_threshold) &&
      value_over_threshold?(:status_reference_threshold, @options[:reference_count], @ng_rule.status_reference_threshold)
  end

  def reaction_match?
    recipient = @options[:recipient]
    return false if @ng_rule.reaction_allow_follower && (recipient.id == @account.id || (!recipient.local? && !@account.local?) || recipient.following?(@account))

    if @options[:reaction_type] == 'emoji_reaction'
      enum_match?(:reaction_type, @options[:reaction_type], @ng_rule.reaction_type) &&
        text_match?(:emoji_reaction_name, @options[:emoji_reaction_name], @ng_rule.emoji_reaction_name) &&
        text_match?(:emoji_reaction_origin_domain, @options[:emoji_reaction_origin_domain], @ng_rule.emoji_reaction_origin_domain)
    else
      enum_match?(:reaction_type, @options[:reaction_type], @ng_rule.reaction_type)
    end
  end

  def check_account_or_record!
    return true unless account_match?

    record!('account', @account.uri, 'account_create') if !@account.local? || @ng_rule.record_history_also_local

    false
  end

  def check_status_or_record!
    return true unless account_match? && status_match?

    text = [@options[:spoiler_text], @options[:text]].compact_blank.join("\n\n")
    data = {
      media_count: @options[:media_count],
      poll_count: @options[:poll_count],
      url: @options[:url],
    }
    record!('status', @options[:uri], "status_#{@options[:reaction_type]}", text: text, data: data) if !@account.local? || @ng_rule.record_history_also_local

    false
  end

  def check_reaction_or_record!
    return true unless account_match? && reaction_match?

    text = @options[:target_status].present? ? [@options[:target_status].spoiler_text, @options[:target_status].text].compact_blank.join("\n\n") : nil
    data = {
      url: @options[:target_status].present? ? @options[:target_status].url : nil,
    }
    record!('reaction', @options[:uri], "reaction_#{@options[:reaction_type]}", text: text, data: data) if !@account.local? || @ng_rule.record_history_also_local

    false
  end

  def loggable_visibility?
    visibility = @options[:target_status]&.visibility || @options[:visibility]
    return true unless visibility

    %i(public public_unlisted login unlisted).include?(visibility.to_sym)
  end

  def self.extract_test!(custom_ng_words)
    detect_keyword?('test', custom_ng_words)
  end

  private

  def followed_by_local_accounts?
    Follow.exists?(account: Account.local, target_account: @account)
  end

  def record!(reason, uri, reason_action, **options)
    opts = options.merge({
      ng_rule: @ng_rule,
      account: @account,
      local: @account.local?,
      reason: reason,
      reason_action: reason_action,
      uri: uri,
    })

    unless loggable_visibility?
      opts = opts.merge({
        text: nil,
        uri: nil,
        hidden: true,
      })
    end

    NgRuleHistory.create!(**opts)
  end

  def text_match?(_reason, text, arr)
    return true if arr.blank? || !text.is_a?(String)

    detect_keyword?(text, arr)
  end

  def enum_match?(_reason, text, arr)
    return true if !text.is_a?(String) || text.blank?

    arr.include?(text)
  end

  def state_match?(_reason, exists, expected)
    case expected.to_sym
    when :needed
      exists
    when :no_needed
      !exists
    else
      true
    end
  end

  def media_state_match?(reason, media, expected)
    state_match?(reason, media.present?, expected)
  end

  def value_over_threshold?(_reason, value, expected)
    return true if !expected.is_a?(Integer) || expected.negative? || !value.is_a?(Integer)

    value > expected
  end

  def detect_keyword?(text, arr)
    Admin::NgRule.detect_keyword?(text, arr)
  end

  class << self
    def string_to_array(text)
      text.delete("\r").split("\n")
    end

    def detect_keyword(text, arr)
      arr = string_to_array(arr) if arr.is_a?(String)

      arr.detect { |word| include?(text, word) ? word : nil }
    end

    def detect_keyword?(text, arr)
      detect_keyword(text, arr).present?
    end

    def include?(text, word)
      if word.start_with?('?') && word.size >= 2
        text =~ /#{word[1..]}/
      else
        text.include?(word)
      end
    end
  end
end
