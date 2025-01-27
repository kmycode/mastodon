# frozen_string_literal: true

module Status::Visibility
  extend ActiveSupport::Concern

  included do
    enum :visibility,
         { public: 0, unlisted: 1, private: 2, direct: 3, limited: 4, public_unlisted: 10, login: 11 },
         suffix: :visibility,
         validate: true
    enum :searchability,
         { public: 0, private: 1, direct: 2, limited: 3, unsupported: 4, public_unlisted: 10 },
         suffix: :searchability
    enum :limited_scope,
         { none: 0, mutual: 1, circle: 2, personal: 3, reply: 4 },
         suffix: :limited

    scope :unset_searchability, -> { where(searchability: nil, reblog_of_id: nil) }
    scope :distributable_visibility, -> { where(visibility: %i(public unlisted)) }
    scope :distributable_visibility_for_anonymous, -> { where(visibility: %i(public public_unlisted unlisted)) }
    scope :list_eligible_visibility, -> { where(visibility: %i(public unlisted private)) }
    scope :not_direct_visibility, -> { where.not(visibility: :direct) }

    validates :visibility, exclusion: { in: %w(direct limited) }, if: :reblog?

    before_validation :set_visibility, unless: :visibility?
    before_validation :set_searchability
  end

  class_methods do
    def selectable_visibilities
      selectable_all_visibilities - %w(mutual circle reply direct)
    end

    def selectable_all_visibilities
      vs = %w(public public_unlisted login unlisted private mutual circle reply direct)
      vs -= %w(public_unlisted) unless Setting.enable_public_unlisted_visibility
      vs -= %w(public) unless Setting.enable_public_visibility
      vs
    end

    def selectable_reblog_visibilities
      %w(unset) + selectable_visibilities
    end

    def all_visibilities
      visibilities.keys
    end

    def selectable_searchabilities
      ss = searchabilities.keys - %w(unsupported)
      ss -= %w(public_unlisted) unless Setting.enable_public_unlisted_visibility
      ss
    end

    def selectable_searchabilities_for_search
      searchabilities.keys - %w(public_unlisted unsupported)
    end

    def all_searchabilities
      searchabilities.keys - %w(unlisted login unsupported)
    end
  end

  def hidden?
    !distributable?
  end

  def distributable?
    public_visibility? || unlisted_visibility? || public_unlisted_visibility?
  end

  alias sign? distributable?

  private

  def set_visibility
    self.visibility ||= reblog.visibility if reblog?
    self.visibility ||= visibility_from_account
  end

  def visibility_from_account
    account.locked? ? :private : :public
  end

  def set_searchability
    return if searchability.nil?

    self.searchability = if %w(public public_unlisted login unlisted).include?(visibility)
                           searchability
                         elsif ['limited', 'direct'].include?(visibility)
                           searchability == 'limited' ? :limited : :direct
                         elsif visibility == 'private'
                           ['public', 'public_unlisted'].include?(searchability) ? :private : searchability
                         else
                           :direct
                         end
  end
end
