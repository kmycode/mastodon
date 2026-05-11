# frozen_string_literal: true

class TextFormatter
  include ActionView::Helpers::TextHelper
  include ERB::Util
  include RoutingHelper

  URL_PREFIX_REGEX = %r{\A(https?://(www\.)?|xmpp:)}

  DEFAULT_REL = %w(nofollow noopener).freeze

  DEFAULT_OPTIONS = {
    multiline: true,
    markdown: false,
  }.freeze

  attr_reader :text, :options

  # @param [String] text
  # @param [Hash] options
  # @option options [Boolean] :multiline
  # @option options [Boolean] :with_domains
  # @option options [Boolean] :with_rel_me
  # @option options [Array<Account>] :preloaded_accounts
  def initialize(text, options = {})
    @text    = text
    @options = DEFAULT_OPTIONS.merge(options)
  end

  def entities
    @entities ||= Extractor.extract_entities_with_indices(text, extract_url_without_protocol: false)
  end

  def to_s
    return add_quote_fallback('').html_safe if text.blank? # rubocop:disable Rails/OutputSafety

    html = rewrite do |entity|
      if entity[:url]
        link_to_url(entity)
      elsif entity[:hashtag]
        link_to_hashtag(entity)
      elsif entity[:screen_name]
        link_to_mention(entity)
      end
    end

    # line first letter for blockquote
    html = markdownify(html.gsub(/^&gt;/, '>')) if markdown?

    html = simple_format(html, {}, sanitize: false).delete("\n") if !markdown? && multiline?
    html = add_quote_fallback(html) if options[:quoted_status].present?
    html = html.delete("\n")

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  class << self
    include ERB::Util
    include ActionView::Helpers::TagHelper

    def shortened_link(url, rel_me: false)
      url = Addressable::URI.parse(url).to_s
      rel = rel_me ? (DEFAULT_REL + %w(me)) : DEFAULT_REL

      prefix      = url.match(URL_PREFIX_REGEX).to_s
      display_url = url[prefix.length, 30]
      suffix      = url[(prefix.length + 30)..]
      cutoff      = url[prefix.length..].length > 30

      if suffix && suffix.length == 1 # revert truncation to account for ellipsis
        display_url += suffix
        suffix = nil
        cutoff = false
      end

      tag.a href: url, target: '_blank', rel: rel.join(' '), translate: 'no' do
        tag.span(prefix, class: 'invisible') +
          tag.span(display_url, class: (cutoff ? 'ellipsis' : '')) +
          tag.span(suffix, class: 'invisible')
      end
    rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
      h(url)
    end

    def link_to_mention(account, with_domain: false)
      url = ActivityPub::TagManager.instance.url_for(account)
      display_username = with_domain ? account.pretty_acct : account.username

      <<~HTML.squish
        <span class="h-card" translate="no"><a href="#{h(url)}" class="u-url mention">@<span>#{h(display_username)}</span></a></span>
      HTML
    end
  end

  private

  def rewrite
    entities.sort_by! do |entity|
      entity[:indices].first
    end

    result = +''

    last_index = entities.reduce(0) do |index, entity|
      indices = entity[:indices]
      result << h(text[index...indices.first])
      result << yield(entity)
      indices.last
    end

    result << h(text[last_index..])

    result
  end

  def link_to_url(entity)
    TextFormatter.shortened_link(entity[:url], rel_me: with_rel_me?)
  end

  def link_to_hashtag(entity)
    hashtag = entity[:hashtag]
    url     = tag_url(hashtag)

    <<~HTML.squish
      <a href="#{h(url)}" class="mention hashtag" rel="tag">#<span>#{h(hashtag)}</span></a>
    HTML
  end

  def link_to_mention(entity)
    username, domain = entity[:screen_name].split('@')
    domain           = nil if local_domain?(domain)
    account          = nil

    if preloaded_accounts?
      same_username_hits = 0

      preloaded_accounts.each do |other_account|
        same_username = other_account.username.casecmp(username).zero?
        same_domain   = other_account.domain.nil? ? domain.nil? : other_account.domain.casecmp(domain)&.zero?

        if same_username && !same_domain
          same_username_hits += 1
        elsif same_username && same_domain
          account = other_account
        end
      end
    else
      account = entity_cache.mention(username, domain)
    end

    return "@#{h(entity[:screen_name])}" if account.nil?

    TextFormatter.link_to_mention(account, with_domain: same_username_hits&.positive? || with_domains?)
  end

  def entity_cache
    @entity_cache ||= EntityCache.instance
  end

  def tag_manager
    @tag_manager ||= TagManager.instance
  end

  delegate :local_domain?, to: :tag_manager

  def multiline?
    options[:multiline]
  end

  def with_domains?
    options[:with_domains]
  end

  def with_rel_me?
    options[:with_rel_me]
  end

  def markdown?
    options[:markdown]
  end

  def preloaded_accounts
    options[:preloaded_accounts]
  end

  def preloaded_accounts?
    preloaded_accounts.present?
  end

  def add_quote_fallback(html)
    return html if options[:quoted_status].nil?

    url = ActivityPub::TagManager.instance.url_for(options[:quoted_status]) || ActivityPub::TagManager.instance.uri_for(options[:quoted_status])
    return html if url.blank? || html.include?(url)

    <<~HTML.squish
      <p class="quote-inline">RE: #{TextFormatter.shortened_link(url)}</p>#{html}
    HTML
  end

  def markdownify(html)
    # not need filter_html because escape is already done
    @htmlobj ||= MyMarkdownHTML.new(
      filter_html: false,
      hard_wrap: true
    )
    @markdown ||= Redcarpet::Markdown.new(@htmlobj,
                                          autolink: false,
                                          tables: false,
                                          disable_indented_code_blocks: false,
                                          fenced_code_blocks: true,
                                          strikethrough: true,
                                          superscript: true,
                                          underline: true,
                                          highlight: false)
    @markdown.render(html)
  end

  class MyMarkdownHTML < Redcarpet::Render::HTML
    def link(_link, _title, _content)
      nil
    end

    def block_code(code, _language)
      "<pre>#{process_program_code(code)}</pre>"
    end

    def codespan(code)
      "<code>#{process_program_code(code)}</code>"
    end

    def header(text, _header_level)
      "<p>#{text}</p>"
    end

    def underline(text)
      text.include?(':') ? nil : "<u>#{text}</u>"
    end

    def image(_link, _title, _alt_text)
      nil
    end

    private

    def process_program_code(code)
      code.gsub("\n", '<br>')
    end
  end
end
