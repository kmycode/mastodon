# frozen_string_literal: true

class RemoveBoostsWideningAudience < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    # add_column :statuses, :searchability, :integer
    # add_column :statuses, :limited_scope, :integer
    Status.find_by_sql(<<~SQL.squish)
      SELECT boost.id
      FROM statuses AS boost
      LEFT JOIN statuses AS boosted ON boost.reblog_of_id = boosted.id
      WHERE
        boost.id > 101746055577600000
        AND (boost.local = TRUE OR boost.uri IS NULL)
        AND boost.visibility IN (0, 1)
        AND boost.reblog_of_id IS NOT NULL
        AND boosted.visibility = 2
    SQL

    # Status.find_by_sql(<<-SQL.squish)
    #   SELECT boost.id
    #   FROM statuses AS boost
    #   LEFT JOIN statuses AS boosted ON boost.reblog_of_id = boosted.id
    #   WHERE
    #     boost.id > 101746055577600000
    #     AND (boost.local = TRUE OR boost.uri IS NULL)
    #     AND boost.visibility IN (0, 1)
    #     AND boost.reblog_of_id IS NOT NULL
    #     AND boosted.visibility = 2
    # SQL

    # Sorry, but remove to fix test
    # RemovalWorker.push_bulk(public_boosts.pluck(:id))

    # remove_column :statuses, :searchability
    # remove_column :statuses, :limited_scope
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
