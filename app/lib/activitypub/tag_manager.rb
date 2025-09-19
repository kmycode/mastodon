# frozen_string_literal: true

require 'singleton'

class ActivityPub::TagManager
  include Singleton
  include JsonLdHelper
  include RoutingHelper

  CONTEXT = 'https://www.w3.org/ns/activitystreams'

  COLLECTIONS = {
    public: 'https://www.w3.org/ns/activitystreams#Public',
  }.freeze

  def public_collection?(uri)
    uri == COLLECTIONS[:public] || %w(as:Public Public).include?(uri)
  end

  def url_for(target)
    return unsupported_uri_scheme?(target.url) ? nil : target.url if target.respond_to?(:local?) && !target.local?

    return unless target.respond_to?(:object_type)

    case target.object_type
    when :person
      target.instance_actor? ? about_more_url(instance_actor: true) : short_account_url(target)
    when :note, :comment, :activity
      return activity_account_status_url(target.account, target) if target.reblog?

      short_account_status_url(target.account, target)
    when :flag
      target.uri
    end
  end

  def uri_for(target, group: false)
    return target.uri if target.respond_to?(:local?) && !target.local?

    return unless target.respond_to?(:object_type)

    case target.object_type
    when :person
      target.instance_actor? ? instance_actor_url : account_url(target)
    when :conversation
      group ? group_context_url(target) : context_url(target)
    when :note, :comment, :activity
      return activity_account_status_url(target.account, target) if target.reblog?

      account_status_url(target.account, target)
    when :emoji
      emoji_url(target)
    when :emoji_reaction
      emoji_reaction_url(target)
    when :flag
      target.uri
    end
  end

  def approval_uri_for(quote, check_approval: true)
    unless quote.quoted_account&.local?
      return 'http://kmy.blue/ns#LegacyQuote' if Setting.auto_accept_legacy_quotes && quote.approval_uri.nil? && InstanceInfo.legacy_quote_software?(quote.quoted_account.domain)

      return quote.approval_uri
    end
    return if check_approval && !quote.accepted?

    account_quote_authorization_url(quote.quoted_account, quote)
  end

  def key_uri_for(target)
    [uri_for(target), '#main-key'].join
  end

  def uri_for_username(username)
    account_url(username: username)
  end

  def generate_uri_for(_target)
    URI.join(root_url, 'payloads', SecureRandom.uuid)
  end

  def activity_uri_for(target)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    activity_account_status_url(target.account, target)
  end

  def context_uri_for(target, page_params = nil)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    items_context_url(target.conversation, page_params)
  end

  def replies_uri_for(target, page_params = nil)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    account_status_replies_url(target.account, target, page_params)
  end

  def references_uri_for(target, page_params = nil)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    account_status_references_url(target.account, target, page_params)
  end

  def likes_uri_for(target)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    account_status_likes_url(target.account, target)
  end

  def shares_uri_for(target)
    raise ArgumentError, 'target must be a local activity' unless %i(note comment activity).include?(target.object_type) && target.local?

    account_status_shares_url(target.account, target)
  end

  def following_uri_for(target, ...)
    raise ArgumentError, 'target must be a local account' unless target.local?

    account_following_index_url(target, ...)
  end

  def followers_uri_for(target, ...)
    return target.followers_url.presence unless target.local?

    account_followers_url(target, ...)
  end

  def collection_uri_for(target, ...)
    raise NotImplementedError unless target.local?

    account_collection_url(target, ...)
  end

  def inbox_uri_for(target)
    raise NotImplementedError unless target.local?

    target.instance_actor? ? instance_actor_inbox_url : account_inbox_url(target)
  end

  def outbox_uri_for(target, ...)
    raise NotImplementedError unless target.local?

    target.instance_actor? ? instance_actor_outbox_url(...) : account_outbox_url(target, ...)
  end

  # Primary audience of a status
  # Public statuses go out to primarily the public collection
  # Unlisted and private statuses go out primarily to the followers collection
  # Others go out only to the people they mention
  def to(status)
    case status.visibility
    when 'public'
      [COLLECTIONS[:public]]
    when 'unlisted', 'public_unlisted', 'private'
      [followers_uri_for(status.account)]
    when 'login'
      [followers_uri_for(status.account), 'as:LoginOnly', 'kmyblue:LoginOnly', 'LoginUser']
    when 'direct'
      if status.account.silenced?
        # Only notify followers if the account is locally silenced
        account_ids = status.active_mentions.pluck(:account_id)
        to = status.account.followers.where(id: account_ids).each_with_object([]) do |account, result|
          result << uri_for(account)
          result << followers_uri_for(account) if account.group?
        end
        to.concat(FollowRequest.where(target_account_id: status.account_id, account_id: account_ids).each_with_object([]) do |request, result|
          result << uri_for(request.account)
          result << followers_uri_for(request.account) if request.account.group?
        end).compact
      else
        status.active_mentions.each_with_object([]) do |mention, result|
          result << uri_for(mention.account)
          result << followers_uri_for(mention.account) if mention.account.group?
        end.compact
      end
    when 'limited'
      # do not empty array to avoid Fedibird personal visibility
      status.conversation.nil? ? ['kmyblue:Limited'] : [context_url(status.conversation)]
    end
  end

  def to_for_friend(status)
    to = to(status)
    to << 'kmyblue:LocalPublic' if status.public_unlisted_visibility?
    to
  end

  # Secondary audience of a status
  # Public statuses go out to followers as well
  # Unlisted statuses go to the public as well
  # Both of those and private statuses also go to the people mentioned in them
  # Direct ones don't have a secondary audience
  def cc(status)
    cc = []

    cc << uri_for(status.reblog.account) if status.reblog?

    case status.visibility
    when 'public'
      cc << followers_uri_for(status.account)
    when 'unlisted', 'public_unlisted'
      cc << COLLECTIONS[:public]
    end

    cc + cc_private_visibility(status)
  end

  def cc_for_misskey(status)
    if status.sending_maybe_compromised_privacy?
      cc = cc_private_visibility(status)
      cc << uri_for(status.reblog.account) if status.reblog?
      return cc
    end

    cc(status)
  end

  def cc_private_visibility(status)
    cc = []

    unless status.direct_visibility? || status.limited_visibility?
      if status.account.silenced?
        # Only notify followers if the account is locally silenced
        account_ids = status.active_mentions.pluck(:account_id)
        cc.concat(status.account.followers.where(id: account_ids).each_with_object([]) do |account, result|
          result << uri_for(account)
          result << followers_uri_for(account) if account.group?
        end.compact)
        cc.concat(FollowRequest.where(target_account_id: status.account_id, account_id: account_ids).each_with_object([]) do |request, result|
          result << uri_for(request.account)
          result << followers_uri_for(request.account) if request.account.group?
        end.compact)
      else
        cc.concat(status.active_mentions.each_with_object([]) do |mention, result|
          result << uri_for(mention.account)
          result << followers_uri_for(mention.account) if mention.account.group?
        end.compact)
      end
    end

    cc
  end

  def local_uri?(uri)
    return false if uri.nil?

    uri  = Addressable::URI.parse(uri)
    host = uri.normalized_host
    host = "#{host}:#{uri.port}" if uri.port

    !host.nil? && (::TagManager.instance.local_domain?(host) || ::TagManager.instance.web_domain?(host))
  end

  def uri_to_local_id(uri, param = :id)
    path_params = Rails.application.routes.recognize_path(uri)
    path_params[:username] = Rails.configuration.x.local_domain if path_params[:controller] == 'instance_actors'
    path_params[param]
  end

  def uris_to_local_accounts(uris)
    usernames = []
    ids = []

    uris.each do |uri|
      param, value = uri_to_local_account_params(uri)
      usernames << value.downcase if param == :username
      ids << value if param == :id
    end

    Account.local.with_username(usernames).or(Account.local.where(id: ids))
  end

  def uri_to_actor(uri)
    uri_to_resource(uri, Account)
  end

  def uri_to_resource(uri, klass, url: false)
    return if uri.nil?

    if local_uri?(uri)
      case klass.name
      when 'Account'
        uris_to_local_accounts([uri]).first
      else
        StatusFinder.new(uri).status
      end
    elsif OStatus::TagManager.instance.local_id?(uri)
      klass.find_by(id: OStatus::TagManager.instance.unique_tag_to_local_id(uri, klass.to_s))
    else
      resource   = klass.find_by(uri: uri.split('#').first)
      resource ||= klass.where('uri != url').find_by(url: uri.split('#').first) if url
      resource
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def limited_scope(status)
    case status.limited_scope
    when 'mutual'
      'Mutual'
    when 'circle'
      'Circle'
    when 'reply'
      'Reply'
    else
      ''
    end
  end

  def searchable_by(status)
    searchable_by =
      case status.compute_searchability_activitypub
      when 'public'
        [COLLECTIONS[:public]]
      when 'private'
        [account_followers_url(status.account)]
      when 'limited'
        ['as:Limited', 'kmyblue:Limited']
      else
        [account_url(status.account)]
      end

    searchable_by.concat(mentions_uris(status)).compact
  end

  def searchable_by_for_friend(status)
    searchable = searchable_by(status)
    searchable << 'kmyblue:LocalPublic' if status.compute_searchability_local == 'public_unlisted'
    searchable
  end

  def account_searchable_by(account)
    case account.compute_searchability_activitypub
    when 'public'
      [COLLECTIONS[:public]]
    when 'private'
      [account_followers_url(account)]
    when 'limited'
      ['as:Limited', 'kmyblue:Limited']
    else
      [account_url(account)]
    end
  end

  def mentions_uris(status)
    if status.account.silenced?
      # Only notify followers if the account is locally silenced
      account_ids = status.active_mentions.pluck(:account_id)
      uris = status.account.followers.where(id: account_ids).each_with_object([]) do |account, result|
        result << uri_for(account)
        result << account_followers_url(account) if account.group?
      end
      uris.concat(FollowRequest.where(target_account_id: status.account_id, account_id: account_ids).each_with_object([]) do |request, result|
        result << uri_for(request.account)
        result << account_followers_url(request.account) if request.account.group?
      end)
    else
      status.active_mentions.each_with_object([]) do |mention, result|
        result << uri_for(mention.account)
        result << account_followers_url(mention.account) if mention.account.group?
      end
    end
  end

  private

  def uri_to_local_account_params(uri)
    return unless local_uri?(uri)

    path_params = Rails.application.routes.recognize_path(uri)

    # TODO: handle numeric IDs
    case path_params[:controller]
    when 'accounts'
      [:username, path_params[:username]]
    when 'instance_actors'
      [:id, -99]
    end
  end
end
