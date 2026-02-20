# frozen_string_literal: true

# Paths handled by the React application, which do not:
# - Require indexing
# - Have alternative format representations

%w(
  /antennas/(*any)
  /blocks
  /bookmarks
  /bookmark_categories/(*any)
  /circles/(*any)
  /collections/(*any)
  /conversations
  /deck/(*any)
  /directory
  /domain_blocks
  /emoji_reactions
  /explore/(*any)
  /favourites
  /follow_requests
  /followed_tags
  /getting-started
  /home
  /keyboard-shortcuts
  /links/(*any)
  /lists/(*any)
  /mutes
  /notifications_v2/(*any)
  /notifications/(*any)
  /pinned
  /public
  /public/local
  /public/local/fixed
  /public/remote
  /publish
  /reaction_deck
  /search
  /start/(*any)
  /statuses/(*any)
).each { |path| get path, to: 'home#index' }
