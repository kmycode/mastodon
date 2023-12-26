# frozen_string_literal: true

module KmyblueCapabilitiesHelper
  def fedibird_capabilities
    capabilities = %i(
      enable_wide_emoji
      kmyblue_searchability
      searchability
      kmyblue_markdown
      kmyblue_reaction_deck
      kmyblue_visibility_login
      status_reference
      visibility_mutual
      visibility_limited
      kmyblue_limited_scope
      kmyblue_antenna
      kmyblue_bookmark_category
      kmyblue_quote
      kmyblue_searchability_limited
      kmyblue_circle_history
      kmyblue_list_notification
    )

    capabilities << :profile_search unless Chewy.enabled?
    if Setting.enable_emoji_reaction
      capabilities << :emoji_reaction
      capabilities << :enable_wide_emoji_reaction
    end
    capabilities << :kmyblue_visibility_public_unlisted if Setting.enable_public_unlisted_visibility
    capabilities << :kmyblue_searchability_public_unlisted if Setting.enable_public_unlisted_visibility
    capabilities << :timeline_no_local unless Setting.enable_local_timeline

    capabilities
  end

  def capabilities_for_nodeinfo
    capabilities = %i(
      enable_wide_emoji
      status_reference
      quote
      emoji_keywords
      circle
    )

    if Setting.enable_emoji_reaction
      capabilities << :emoji_reaction
      capabilities << :enable_wide_emoji_reaction
    end

    capabilities
  end
end
