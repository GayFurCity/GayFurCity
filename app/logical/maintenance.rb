# frozen_string_literal: true

module Maintenance
  module_function

  def daily
    ignoring_exceptions { PostPruner.new.prune! }
    ignoring_exceptions { ForumTopicStatus.process_all_subscriptions! }
    ignoring_exceptions { Tag.clean_up_negative_post_counts! }
    ignoring_exceptions { TagAlias.fix_nonzero_post_counts! }
    ignoring_exceptions { TagAlias.update_cached_post_counts_for_all }
    ignoring_exceptions { UserPasswordResetNonce.prune! }
    ignoring_exceptions { StatsUpdater.run! }
    ignoring_exceptions { DiscordReport::JanitorStats.new.run! }
    ignoring_exceptions { DiscordReport::ModeratorStats.new.run! }
    ignoring_exceptions { DiscordReport::AiburStats.new.run! }
    ignoring_exceptions { Recommender.train! }
  end

  def hourly
    ignoring_exceptions { Post.document_store.import_views }
    ignoring_exceptions { MediaAsset.prune_expired! }
  end

  def ignoring_exceptions
    ActiveRecord::Base.connection.execute("set statement_timeout = 0")
    yield
  rescue StandardError => e
    GayFurCity::Logger.log(e)
  end
end
