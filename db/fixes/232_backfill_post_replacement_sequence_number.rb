#!/usr/bin/env ruby
# frozen_string_literal: true

# Backfills sequence_number on post_replacements.
# Establishes the invariant 0 = the original backup, 1..N = replacements in creation (id) order
# within each post.
#
# Two set-based UPDATEs, not per-row Ruby. The original is numbered by status, so a legacy
# "misordered" backup (higher id than the replacement it backed up) still sorts first.
# 0 is reserved for the original, so posts without one simply start at 1.
# Idempotent: the assignment is deterministic, so re-running yields the same result.
#
# Run only while replacement creation is frozen so no new NULL rows appear mid-run.

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

PostReplacement.without_timeout do
  conn = PostReplacement.connection

  originals = conn.execute(<<~SQL.squish).cmd_tuples
    UPDATE post_replacements SET sequence_number = 0 WHERE status = 'original'
  SQL

  replacements = conn.execute(<<~SQL.squish).cmd_tuples
    UPDATE post_replacements pr SET sequence_number = sub.rn
    FROM (
      SELECT id, row_number() OVER (PARTITION BY post_id ORDER BY id) AS rn
      FROM post_replacements WHERE status <> 'original'
    ) sub
    WHERE pr.id = sub.id
  SQL

  puts("Backfilled sequence_number: #{originals} originals (0), #{replacements} replacements (1..N)")
end
