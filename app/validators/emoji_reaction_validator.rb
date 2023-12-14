# frozen_string_literal: true

class EmojiReactionValidator < ActiveModel::Validator
  SUPPORTED_EMOJIS = Oj.load_file(Rails.root.join('app', 'javascript', 'mastodon', 'features', 'emoji', 'emoji_map.json').to_s).keys.freeze

  def validate(emoji_reaction)
    return if emoji_reaction.name.blank?

    emoji_reaction.errors.add(:name, I18n.t('reactions.errors.unrecognized_emoji')) if emoji_reaction.custom_emoji_id.blank? && !unicode_emoji?(emoji_reaction.name)
    emoji_reaction.errors.add(:name, I18n.t('reactions.errors.unrecognized_emoji')) if emoji_reaction.custom_emoji_id.present? && disabled_custom_emoji?(emoji_reaction.custom_emoji)
    emoji_reaction.errors.add(:name, I18n.t('reactions.errors.banned')) if deny_emoji_reactions?(emoji_reaction)
    emoji_reaction.errors.add(:name, I18n.t('reactions.errors.banned')) if blocking?(emoji_reaction) || domain_blocking?(emoji_reaction)
  end

  private

  def unicode_emoji?(name)
    SUPPORTED_EMOJIS.include?(name)
  end

  def disabled_custom_emoji?(custom_emoji)
    custom_emoji.nil? ? false : custom_emoji.disabled
  end

  def deny_emoji_reactions?(emoji_reaction)
    !emoji_reaction.status.account.allow_emoji_reaction?(emoji_reaction.account)
  end

  def blocking?(emoji_reaction)
    return false if !emoji_reaction.status.local? || emoji_reaction.status.account == emoji_reaction.account

    emoji_reaction.status.account.blocking?(emoji_reaction.account)
  end

  def domain_blocking?(emoji_reaction)
    return false unless !emoji_reaction.account.local? && emoji_reaction.status.local?

    emoji_reaction.status.account.domain_blocking?(emoji_reaction.account.domain)
  end
end
