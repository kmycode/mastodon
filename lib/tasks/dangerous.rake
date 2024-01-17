# frozen_string_literal: true
# rubocop:disable all

namespace :dangerous do
  task :back_upstream do
    require './config/environment'

    prompt = TTY::Prompt.new

    exit(0) unless prompt.yes?('[1/3] Do you really want to go back to the original Mastodon?', default: false)
    exit(0) unless prompt.yes?('[2/3] All proprietary data of kmyblue will be deleted and cannot be restored. Are you sure?', default: false)
    exit(0) unless prompt.yes?('[3/3] This operation is irreversible. You have backups in case this operation causes a system malfunction, do you not?', default: false)

    target_migrations = %w(
      20231022074913
      20231021005339
      20230314120530
      20240109035435
      20231214225249
      20231212225737
      20231130083634
      20231130031209
      20231115001356
      20231105225839
      20231028005948
      20231028004612
      20231023083359
      20231009235215
      20231007090808
      20231006030102
      20231005074832
      20231001050733
      20231001031337
      20230930233930
      20230923103430
      20230919232836
      20230911022527
      20230826023400
      20230821061713
      20230819084858
      20230812130612
      20230812083752
      20230804222017
      20230714004824
      20230706031715
      20230705232953
      20230522093135
      20230522082252
      20230521122642
      20230514030455
      20230512122757
      20230510033040
      20230510004621
      20230510000439
      20230509045358
      20230430110057
      20230428111230
      20230427233749
      20230427122753
      20230427072650
      20230427022606
      20230426013738
      20230423233429
      20230423002728
      20230420081634
      20230414010523
      20230412073021
      20230412005311
      20230410004651
      20230406041523
      20230405121625
      20230405121613
      20230320234918
      20230314121142
      20230314081013
      20230314021909
      20230308061833
      20230223102416
      20230222232121
      20240117021025
    )
    # Removed: account_groups
    target_tables = %w(
      antennas
      antenna_accounts
      antenna_domains
      antenna_tags
      bookmark_categories
      bookmark_category_statuses
      circles
      circle_accounts
      circle_statuses
      emoji_reactions
      friend_domains
      instance_infos
      list_statuses
      scheduled_expiration_statuses
      status_capability_tokens
      status_references
    )
    target_table_columns = [
      # Removed: accounts dissubscribable
      %w(accounts group_allow_private_message),
      # Removed: accounts group_message_following_only
      %w(accounts master_settings),
      %w(accounts searchability),
      %w(accounts settings),
      # Removed: accounts stop_emoji_reaction_streaming
      %w(account_stats group_activitypub_count),
      %w(account_statuses_cleanup_policies keep_self_emoji),
      %w(account_statuses_cleanup_policies min_emojis),
      %w(conversations ancestor_status_id),
      %w(conversations inbox_url),
      %w(custom_emojis aliases),
      %w(custom_emojis image_height),
      %w(custom_emojis image_width),
      %w(custom_emojis is_sensitive),
      %w(custom_emojis license),
      %w(custom_filters exclude_follows),
      %w(custom_filters exclude_localusers),
      %w(custom_filters with_quote),
      %w(domain_blocks detect_invalid_subscription),
      %w(domain_blocks hidden),
      # Removed: domain_blocks hidden_anonymous
      %w(domain_blocks reject_favourite),
      %w(domain_blocks reject_friend),
      %w(domain_blocks reject_hashtag),
      %w(domain_blocks reject_new_follow),
      %w(domain_blocks reject_reply),
      %w(domain_blocks reject_reply_exclude_followers),
      %w(domain_blocks reject_send_dissubscribable),
      %w(domain_blocks reject_send_media),
      %w(domain_blocks reject_send_not_public_searchability),
      %w(domain_blocks reject_send_public_unlisted),
      # Removed: domain_blocks reject_send_unlisted_dissubscribable
      %w(domain_blocks reject_send_sensitive),
      %w(domain_blocks reject_straight_follow),
      %w(lists notify),
      %w(statuses limited_scope),
      %w(statuses markdown),
      %w(statuses quote_of_id),
      %w(statuses searchability),
      %w(status_edits markdown),
      %w(status_stats emoji_reactions),
      %w(status_stats emoji_reactions_count),
      %w(status_stats emoji_reaction_accounts_count),
      %w(status_stats status_referred_by_count),
      # Removed: status_stats test
    ]
    target_indices = %w(
      index_statuses_on_url
      index_statuses_on_conversation_id
    )

    prompt.say 'Processing...'
    ActiveRecord::Base.connection.execute('UPDATE statuses SET visibility = 1 WHERE visibility IN (10, 11)')
    ActiveRecord::Base.connection.execute('UPDATE custom_filters SET action = 0 WHERE action = 2')
    ActiveRecord::Base.connection.execute('UPDATE account_warnings SET action = 1250 WHERE action = 1200')
    ActiveRecord::Base.connection.execute('CREATE INDEX IF NOT EXISTS index_statuses_local_20190824 ON statuses USING btree (id DESC, account_id) WHERE (local OR (uri IS NULL)) AND deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))')
    ActiveRecord::Base.connection.execute('CREATE INDEX IF NOT EXISTS index_statuses_public_20200119 ON statuses USING btree (id DESC, account_id) WHERE deleted_at IS NULL AND visibility = 0 AND reblog_of_id IS NULL AND ((NOT reply) OR (in_reply_to_account_id = account_id))')
    ActiveRecord::Base.connection.execute('DROP INDEX IF EXISTS index_statuses_local_20231213')
    ActiveRecord::Base.connection.execute('DROP INDEX IF EXISTS index_statuses_public_20231213')
    ActiveRecord::Base.connection.execute('ALTER TABLE ONLY custom_filter_keywords ALTER COLUMN whole_word SET DEFAULT true')
    prompt.ok 'Proceed'

    prompt.say 'Removing migration histories...'
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations WHERE version IN ('#{target_migrations.join("','")}')")
    prompt.ok 'Removed'

    prompt.say 'Removing tables...'
    target_tables.each do |table_name|
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table_name} CASCADE")
    end
    prompt.ok 'Removed'

    prompt.say 'Removing table columns...'
    target_table_columns.each do |table_name, column_name|
      ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} DROP COLUMN IF EXISTS #{column_name}")
    end
    prompt.ok 'Removed'

    prompt.say 'Removing indices...'
    target_indices.each do |index_name|
      ActiveRecord::Base.connection.execute("DROP INDEX IF EXISTS #{index_name}")
    end
    prompt.ok 'Removed'

    prompt.ok 'Done!'
    prompt.say "\n"
    prompt.ok 'Thanks for using kmyblue. Good bye!'
  end
end

# rubocop:enable all
