# frozen_string_literal: true

class ActivityPub::Parser::StatusParser
  include JsonLdHelper

  # @param [Hash] json
  # @param [Hash] magic_values
  # @option magic_values [String] :followers_collection
  def initialize(json, magic_values = {})
    @json         = json
    @object       = magic_values[:object] || json['object'] || json
    @magic_values = magic_values
    @account      = magic_values[:account]
    @friend       = magic_values[:friend_domain]
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
    @object['published']&.to_datetime
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
    elsif audience_to.include?('LocalPublic') && @friend
      :public_unlisted
    elsif audience_cc.any? { |cc| ActivityPub::TagManager.instance.public_collection?(cc) }
      :unlisted
    elsif audience_to.include?('as:LoginOnly') || audience_to.include?('LoginUser')
      :login
    elsif audience_to.include?(@magic_values[:followers_collection])
      :private
    else
      :direct
    end
  end

  def searchability
    from_audience = searchability_from_audience
    return from_audience if from_audience
    return nil if default_searchability_from_bio?

    searchability_from_bio || (misskey_software? ? misskey_searchability : nil)
  end

  def limited_scope
    case @object['limitedScope']
    when 'Mutual'
      :mutual
    when 'Circle'
      :circle
    else
      :none
    end
  end

  def language
    @language ||= original_language || (misskey_software? ? 'ja' : nil)
  end

  def original_language
    if content_language_map?
      @object['contentMap'].keys.first
    elsif name_language_map?
      @object['nameMap'].keys.first
    elsif summary_language_map?
      @object['summaryMap'].keys.first
    end
  end

  private

  def audience_to
    as_array(@object['to'] || @json['to']).map { |x| value_or_id(x) }
  end

  def audience_cc
    as_array(@object['cc'] || @json['cc']).map { |x| value_or_id(x) }
  end

  def audience_searchable_by
    return nil if @object['searchableBy'].nil?

    @audience_searchable_by = as_array(@object['searchableBy']).map { |x| value_or_id(x) }
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

  def instance_info
    @instance_info ||= InstanceInfo.find_by(domain: @account.domain)
  end

  def misskey_software?
    info = instance_info
    return false if info.nil?

    %w(misskey calckey).include?(info.software)
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
    if audience_searchable_by.nil?
      nil
    elsif audience_searchable_by.any? { |uri| ActivityPub::TagManager.instance.public_collection?(uri) }
      :public
    elsif audience_searchable_by.include?('as:Limited')
      :limited
    elsif audience_searchable_by.include?('LocalPublic') && @friend
      :public_unlisted
    elsif audience_searchable_by.include?(@account.followers_url)
      :private
    else
      :direct
    end
  end
end
