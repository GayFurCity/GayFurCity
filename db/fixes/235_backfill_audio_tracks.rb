#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs AudioTrackExtractionJob for every video post that doesn't yet have an audio track for its
# current file - i.e. every post uploaded before this feature existed, plus any post whose file
# has since been replaced without ever getting a track re-extracted for the replacement. Silent
# videos are handled by the job itself (it no-ops when there's no embedded audio stream).
#
# Runs perform_now, not perform_later - the later-numbered ES fixers (has_pending_audio,
# audiocount) compute their values by querying audio_tracks as it exists when THEY run, so this
# needs to actually finish creating those rows now, not just get them queued for whenever the job
# queue gets around to it. Safe to re-run: posts that already have a track for their current file
# (including ones this same run already created) are skipped by the WHERE NOT EXISTS below.

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))
requires_migration!("20260831140100")

count = 0
Post.without_timeout do
  Post.joins(:media_asset)
      .where("upload_media_assets.file_ext": FileMethods::VIDEO_EXTENSIONS)
      .where.not(
        "EXISTS (SELECT 1 FROM audio_tracks WHERE audio_tracks.post_id = posts.id AND audio_tracks.file_md5 = upload_media_assets.md5)",
      )
      .find_each do |post|
        AudioTrackExtractionJob.perform_now(post.upload_media_asset_id)
        count += 1
      end
end

puts("Ran audio track extraction for #{count} video posts")
