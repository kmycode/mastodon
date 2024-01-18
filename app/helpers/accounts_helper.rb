# frozen_string_literal: true

module AccountsHelper
  def display_name(account, **options)
    str = account.display_name.presence || account.username

    if options[:custom_emojify]
      prerender_custom_emojis(h(str), account.emojis)
    else
      str
    end
  end

  def acct(account)
    if account.local?
      "@#{account.acct}@#{site_hostname}"
    else
      "@#{account.pretty_acct}"
    end
  end

  def account_action_button(account)
    return if account.memorial? || account.moved?

    link_to ActivityPub::TagManager.instance.url_for(account), class: 'button logo-button', target: '_new' do
      safe_join([logo_as_symbol, t('accounts.follow')])
    end
  end

  def account_formatted_stat(value)
    number_to_human(value, precision: 3, strip_insignificant_zeros: true)
  end

  def account_description(account)
    prepend_str = [
      [
        account_formatted_stat(account.public_statuses_count),
        I18n.t('accounts.posts', count: account.public_statuses_count),
      ].join(' '),

      [
        account_formatted_stat(account.public_following_count),
        I18n.t('accounts.following', count: account.public_following_count),
      ].join(' '),

      [
        account_formatted_stat(account.public_followers_count),
        I18n.t('accounts.followers', count: account.public_followers_count),
      ].join(' '),
    ].join(', ')

    [prepend_str, account.note].join(' · ')
  end
end
