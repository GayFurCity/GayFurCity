#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))
requires_migration!("20260903112129")

Post.without_timeout do
  conn = Post.connection

  pools = conn.execute(<<~SQL.squish).cmd_tuples
    UPDATE posts SET pool_ids = agg.ids
    FROM (SELECT unnest(post_ids) AS post_id, ARRAY_AGG(id ORDER BY id) AS ids FROM pools GROUP BY 1) agg
    WHERE posts.id = agg.post_id
  SQL

  public_sets = conn.execute(<<~SQL.squish).cmd_tuples
    UPDATE posts SET public_set_ids = agg.ids
    FROM (SELECT unnest(post_ids) AS post_id, ARRAY_AGG(id ORDER BY id) AS ids FROM post_sets WHERE is_public GROUP BY 1) agg
    WHERE posts.id = agg.post_id
  SQL

  private_sets = conn.execute(<<~SQL.squish).cmd_tuples
    UPDATE posts SET private_set_ids = agg.ids
    FROM (SELECT unnest(post_ids) AS post_id, ARRAY_AGG(id ORDER BY id) AS ids FROM post_sets WHERE NOT is_public GROUP BY 1) agg
    WHERE posts.id = agg.post_id
  SQL

  puts("Backfilled pool_ids for #{pools} posts, public_set_ids for #{public_sets} posts, private_set_ids for #{private_sets} posts")
end
