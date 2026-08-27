# frozen_string_literal: true

class AddTimeoutConfigOptions < ExtendedMigration[7.1]
  def change
    add_column(:config, :postgres_query_timeout, :jsonb, default: {
      User::Levels::ANONYMOUS    => 3_000,
      User::Levels::TRUSTED      => 6_000,
      User::Levels::FORMER_STAFF => 9_000,
    }, null: false)

    add_column(:config, :elasticsearch_query_timeout, :jsonb, default: {
      User::Levels::ANONYMOUS    => 3_000,
      User::Levels::TRUSTED      => 6_000,
      User::Levels::FORMER_STAFF => 9_000,
    }, null: false)

    add_column(:config, :elasticsearch_request_timeout, :jsonb, default: {
      User::Levels::ANONYMOUS    => 5,
      User::Levels::TRUSTED      => 10,
      User::Levels::FORMER_STAFF => 15,
    }, null: false)

    add_column(:config, :request_cycle_timeout, :jsonb, default: {
      User::Levels::ANONYMOUS    => 10_000,
      User::Levels::TRUSTED      => 20_000,
      User::Levels::FORMER_STAFF => 30_000,
    }, null: false)

    AdminConfig.delete_cache
  end
end
