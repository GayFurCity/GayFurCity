# frozen_string_literal: true

require_relative("../../app/logical/cache")
require_relative("../../lib/prometheus/client/data_stores/redis")

pool = ConnectionPool.new(size: ENV.fetch("GAYFURCITY_METRICS_REDIS_POOL_SIZE", 5), timeout: 5) { Cache.redis }
Prometheus::Client.config.data_store = Prometheus::Client::DataStores::Redis.new(connection_pool: pool)

# The metrics collector below runs off the request cycle (see config/pitchfork.rb, where only
# worker 0 hosts the /metrics exporter in a background thread inside that worker's process). Giving
# it its own connection pool, instead of sharing ActiveRecord::Base's, keeps a slow or bursty scrape
# from starving that worker's normal request handling of connections (and vice versa).
class MetricsRecord < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
  self.abstract_class = true

  # reltuples is a planner estimate, not an exact count, but it's cheap (catalog lookup, no
  # table scan) and plenty accurate for an unfiltered table-size gauge. Postgres reports -1 when
  # the table has never been analyzed, in which case fall back to a real count.
  def self.estimated_count(table_name)
    estimate = connection.select_value(<<~SQL.squish).to_i
      SELECT reltuples FROM pg_class WHERE oid = #{connection.quote(table_name)}::regclass
    SQL
    return estimate if estimate >= 0

    connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table_name)}").to_i
  end

  def self.exact_count(relation)
    connection.select_value(relation.select(Arel.sql("COUNT(*)")).to_sql).to_i
  end
end
MetricsRecord.establish_connection(
  ActiveRecord::Base.connection_db_config.configuration_hash.merge(pool: ENV.fetch("GAYFURCITY_METRICS_DB_POOL_SIZE", 2).to_i),
)

Yabeda.configure do
  default_tag(:env, Rails.env)
  default_tag(:server, GayFurCity.config.server_name)
  default_tag(:version, GayFurCity.config.version)

  group(:storage) do
    %i[store delete open exists move_file].each do |method|
      counter(:"#{method}", comment: "A counter of storage #{method} calls", tags: %i[class])
      counter(:"#{method}_failures", comment: "A counter of failed storage #{method} calls", tags: %i[class])
      histogram(:"#{method}_runtime", comment: "The runtime of storage #{method} calls", tags: %i[class], unit: :seconds, buckets: Prometheus::Client::Histogram::DEFAULT_BUCKETS)
    end
  end

  group(:jobs) do
    counter(:executions, comment: "A counter of background job executions", tags: %i[job_class])
    counter(:failures, comment: "A counter of failed background job executions", tags: %i[job_class])
    histogram(:runtime, comment: "How long background jobs take to execute", tags: %i[job_class], unit: :seconds, buckets: Prometheus::Client::Histogram::DEFAULT_BUCKETS)
  end

  group(:site) do
    gauge(:total_posts, comment: "The total number of posts")
    gauge(:total_active_posts, comment: "The total number of non-deleted posts")
    gauge(:total_deleted_posts, comment: "The total number of deleted posts")
    gauge(:total_pending_posts, comment: "The total number of pending posts")

    gauge(:total_users, comment: "The total number of users")
    gauge(:total_tags, comment: "The total number of tags")

    gauge(:total_comments, comment: "The total number of comments")
    gauge(:total_forum_posts, comment: "The total number of forum posts")

    gauge(:pending_tickets, comment: "The total number of pending tickets")
    gauge(:pending_bulk_update_requests, comment: "The total number of pending bulk update requests")
  end

  collect do
    # The /metrics rack app (config/pitchfork.rb, config/puma.rb) runs outside the Rails
    # middleware stack, so nothing checks connections back in after the request the way
    # ActiveRecord::ConnectionAdapters::ConnectionManagement normally would. Without
    # with_connection here, every scrape leases a MetricsRecord connection on a fresh
    # WEBrick thread and never returns it, quietly exhausting the pool scrape by scrape.
    # estimated_count/exact_count call .connection themselves, which marks the checkout
    # sticky (permanent) unless prevent_permanent_checkout forces it to release anyway.
    MetricsRecord.with_connection(prevent_permanent_checkout: true) do
      site.total_posts.set({}, MetricsRecord.estimated_count(Post.table_name))
      site.total_active_posts.set({}, MetricsRecord.exact_count(Post.not_deleted))
      site.total_deleted_posts.set({}, MetricsRecord.exact_count(Post.deleted))
      site.total_pending_posts.set({}, MetricsRecord.exact_count(Post.pending))

      site.total_users.set({}, MetricsRecord.estimated_count(User.table_name))
      site.total_tags.set({}, MetricsRecord.estimated_count(Tag.table_name))

      site.total_comments.set({}, MetricsRecord.estimated_count(Comment.table_name))
      site.total_forum_posts.set({}, MetricsRecord.estimated_count(ForumPost.table_name))

      site.pending_tickets.set({}, MetricsRecord.exact_count(Ticket.pending))
      site.pending_bulk_update_requests.set({}, MetricsRecord.exact_count(BulkUpdateRequest.pending))
    end
  end
end

# /metrics runs the collect block above on every scrape, which is a handful of sequential
# COUNT(*)/estimate queries and can take a while under load. Add a /up route alongside it on
# the same internal port that just answers instantly, so uptime checks don't have to pay for
# a full metrics collection. This patches the one method both server configs build their rack
# app from (config/puma.rb via the yabeda-puma-plugin, config/pitchfork.rb directly), so it
# covers both without duplicating the rack app setup in each.
module Yabeda
  module Prometheus
    class Exporter
      UP_HANDLER = ->(_env) do
        [200, { "Content-Type" => "text/plain" }, ["OK\n"]]
      end.freeze

      class << self
        alias metrics_rack_app rack_app

        def rack_app(exporter = self, **)
          ::Rack::URLMap.new("/up" => UP_HANDLER, "/" => metrics_rack_app(exporter, **))
        end
      end
    end
  end
end
