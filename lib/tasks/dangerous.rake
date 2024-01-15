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
    )
    target_tables = %w(
    )
    target_table_columns = [
      # %w(accounts dissubscribable)
    ]
    target_indices = %w(
    )

    prompt.say 'Processing...'
    ActiveRecord::Base.connection.execute('UPDATE statuses SET visibility = 1 WHERE visibility IN (10, 11)')
    ActiveRecord::Base.connection.execute('UPDATE custom_filters SET action = 0 WHERE action = 2')
    prompt.ok 'Proceed'

    prompt.say 'Removing migration histories...'
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations WHERE version IN ('#{target_migrations.join("','")}')")
    prompt.ok 'Removed'

    prompt.say 'Removing tables...'
    target_tables.each do |table_name|
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table_name}")
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
