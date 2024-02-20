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

  def status_match?
    @options[:mention_count] = 0 if @ng_rule.status_mention_threshold_stranger_only && !(@options[:mention_to_stranger])

    has_media = @options[:media_count].is_a?(Integer) && @options[:media_count].positive?
    has_poll = @options[:poll_count].is_a?(Integer) && @options[:poll_count].positive?

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
      state_match?(:status_quote_state, @options[:quote].present?, @ng_rule.status_quote_state) &&
      state_match?(:status_reply_state, @options[:reply].presence, @ng_rule.status_reply_state) &&
      value_over_threshold?(:status_media_threshold, @options[:media_count], @ng_rule.status_media_threshold) &&
      value_over_threshold?(:status_poll_threshold, @options[:poll_count], @ng_rule.status_poll_threshold) &&
      value_over_threshold?(:status_mention_threshold, @options[:mention_count], @ng_rule.status_mention_threshold) &&
      value_over_threshold?(:status_reference_threshold, @options[:reference_count], @ng_rule.status_reference_threshold)
  end

  def reaction_match?
    return false if @ng_rule.reaction_allow_follower && @options[:following]

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

    record!('account', @account.uri)

    !violation?
  end

  def check_status_or_record!
    return true unless account_match? && status_match?

    record!('status', @options[:uri], text: "#{@options[:spoiler_text]}\n\n#{@options[:text]}") if !@options.key?(:visibility) || %i(public public_unlisted login unlsited).include?(@options[:visibility].to_sym)

    !violation?
  end

  def check_reaction_or_record!
    return true unless account_match? && reaction_match?

    record!('reaction', @options[:uri])

    !violation?
  end

  private

  def include?(text, word)
    if word.start_with?('?') && word.size >= 2
      text =~ /#{word[1..]}/
    else
      text.include?(word)
    end
  end

  def already_did_count
    return @already_did_count if defined?(@already_did_count)

    @already_did_count = NgRuleHistory.count(ng_rule: @ng_rule, account: @account)
  end

  def violation?
    limit = @ng_rule.rule_violation_threshold_per_account
    limit = 1 unless limit.is_a?(Integer)

    return false unless limit.positive?
    return true if limit <= 1

    already_did_count >= limit - 1
  end

  def record!(reason, uri, **options)
    opts = options.merge({
      ng_rule: @ng_rule,
      account: @account,
      reason: reason,
      uri: uri,
    })
    opts = opts.merge({ skip_count: already_did_count, skip: true }) unless violation?
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
