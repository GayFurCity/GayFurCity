# frozen_string_literal: true

require_relative("../../app/logical/cache")
require_relative("../../lib/prometheus/client/data_stores/redis")

pool = ConnectionPool.new(size: 5, timeout: 5) { Cache.redis }
Prometheus::Client.config.data_store = Prometheus::Client::DataStores::Redis.new(connection_pool: pool)

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
    site.total_posts.set({}, Post.count)
    site.total_active_posts.set({}, Post.not_deleted.count)
    site.total_deleted_posts.set({}, Post.deleted.count)
    site.total_pending_posts.set({}, Post.pending.count)

    site.total_users.set({}, User.count)
    site.total_tags.set({}, Tag.count)

    site.total_comments.set({}, Comment.count)
    site.total_forum_posts.set({}, ForumPost.count)

    site.pending_tickets.set({}, Ticket.pending.count)
    site.pending_bulk_update_requests.set({}, BulkUpdateRequest.pending.count)
  end
end
