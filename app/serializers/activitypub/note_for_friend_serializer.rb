# frozen_string_literal: true

class ActivityPub::NoteForFriendSerializer < ActivityPub::NoteSerializer
  def to
    ActivityPub::TagManager.instance.to_for_friend(object)
  end

  def searchable_by
    ActivityPub::TagManager.instance.searchable_by_for_friend(object)
  end
end
