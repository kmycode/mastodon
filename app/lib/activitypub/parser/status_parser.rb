# frozen_string_literal: true

class ActivityPub::Parser::StatusParser
  include JsonLdHelper

  NORMALIZED_LOCALE_NAMES = LanguagesHelper::SUPPORTED_LOCALES.keys.index_by(&:downcase).freeze

  # @param [Hash] json
  # @param [Hash] options
  # @option options [String] :followers_collection
  # @option options [Hash]   :object
  def initialize(json, **options)
    @json    = json
    @object  = options[:object] || json['object'] || json
    @options = options
    @account = options[:account]
    @friend  = options[:friend_domain]
  end

  def uri
    id = @object['id']

    if id&.start_with?('bear:')
      Addressable::URI.parse(id).query_values['u']
    else
      id
    end
  rescue Addressable::URI::InvalidURIError
    id
  end

  def url
    url_to_href(@object['url'], 'text/html') if @object['url'].present?
  end

  def text
    if @object['content'].present?
      @object['content']
    elsif content_language_map?
      @object['contentMap'].values.first
    end
  end

  def spoiler_text
    if @object['summary'].present?
      @object['summary']
    elsif summary_language_map?
      @object['summaryMap'].values.first
    end
  end

  def title
    if @object['name'].present?
      @object['name']
    elsif name_language_map?
      @object['nameMap'].values.first
    end
  end

  def created_at
    datetime = @object['published']&.to_datetime
    datetime if datetime.present? && (0..9999).cover?(datetime.year)
  rescue ArgumentError
    nil
  end

  def edited_at
    @object['updated']&.to_datetime
  rescue ArgumentError
    nil
  end

  def reply
    @object['inReplyTo'].present?
  end

  def sensitive
    @object['sensitive']
  end

  def visibility
    if audience_to.any? { |to| ActivityPub::TagManager.instance.public_collection?(to) }
      :public
    elsif audience_to.include?('kmyblue:LocalPublic') && @friend
      :public_unlisted
    elsif audience_cc.any? { |cc| ActivityPub::TagManager.instance.public_collection?(cc) }
      :unlisted
    elsif audience_to.include?('kmyblue:LoginOnly') || audience_to.include?('as:LoginOnly') || audience_to.include?('LoginUser')
      :login
    elsif audience_to.include?(@options[:followers_collection])
      :private
    else
      :direct
    end
  end

  def distributable_visibility?
    %i(public public_unlisted unlisted login).include?(visibility)
  end

  def searchability
    from_audience = searchability_from_audience
    return from_audience if from_audience
    return nil if default_searchability_from_bio?

    searchability_from_bio || (invalid_subscription_software? ? misskey_searchability : nil)
  end

  def limited_scope
    case @object['limitedScope']
    when 'Mutual'
      :mutual
    when 'Circle'
      :circle
    when 'Reply'
      :reply
    else
      :none
    end
  end

  def language
    lang = raw_language_code || (no_language_flag_software? ? 'ja' : nil)
    lang.presence && NORMALIZED_LOCALE_NAMES.fetch(lang.downcase.to_sym, lang)
  end

  private

  def raw_language_code
    if content_language_map?
      @object['contentMap'].keys.first
    elsif name_language_map?
      @object['nameMap'].keys.first
    elsif summary_language_map?
      @object['summaryMap'].keys.first
    end
  end

  def audience_to
    as_array(@object['to'] || @json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@object['cc'] || @json['cc']).map { |x| value_or_id(x) }
  end

  def audience_searchable_by
    return nil if @object['searchableBy'].nil?

    @audience_searchable_by = as_array(@object['searchableBy']).map { |x| value_or_id(x) }.compact_blank
  end

  def summary_language_map?
    @object['summaryMap'].is_a?(Hash) && !@object['summaryMap'].empty?
  end

  def content_language_map?
    @object['contentMap'].is_a?(Hash) && !@object['contentMap'].empty?
  end

  def name_language_map?
    @object['nameMap'].is_a?(Hash) && !@object['nameMap'].empty?
  end

  def no_language_flag_software?
    InstanceInfo.no_language_flag_software?(@account.domain)
  end

  def invalid_subscription_software?
    InstanceInfo.invalid_subscription_software?(@account.domain)
  end

  def misskey_searchability
    %i(public unlisted).include?(visibility) ? :public : :limited
  end

  SCAN_SEARCHABILITY_RE = /\[searchability:(public|followers|reactors|private)\]/
  SCAN_SEARCHABILITY_FEDIBIRD_RE = /searchable_by_(all_users|followers_only|reacted_users_only|nobody)/

  def default_searchability_from_bio?
    note = @account.note
    return false if note.blank?

    note.include?('searchable_by_default_range')
  end

  def searchability_from_bio
    note = @account.note
    return nil if note.blank?

    searchability_bio = note.scan(SCAN_SEARCHABILITY_FEDIBIRD_RE).first || note.scan(SCAN_SEARCHABILITY_RE).first
    return nil unless searchability_bio

    searchability = searchability_bio[0]
    return nil if searchability.nil?

    searchability = :public  if %w(public all_users).include?(searchability)
    searchability = :private if %w(followers followers_only).include?(searchability)
    searchability = :direct  if %w(reactors reacted_users_only).include?(searchability)
    searchability = :limited if %w(private nobody).include?(searchability)

    searchability
  end

  def searchability_from_audience
    return nil if audience_searchable_by.blank?
    return :limited if audience_searchable_by.include?('kmyblue:Limited') || audience_searchable_by.include?('as:Limited')

    if audience_searchable_by.any? { |uri| ActivityPub::TagManager.instance.public_collection?(uri) }
      :public
    elsif audience_searchable_by.include?('kmyblue:LocalPublic') && @friend
      :public_unlisted
    elsif audience_searchable_by.include?(@account.followers_url)
      :private
    elsif audience_searchable_by.include?(@account.uri) || audience_searchable_by.include?(@account.url)
      :direct
    else
      :limited
    end
  end
end
