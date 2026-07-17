# frozen_string_literal: true

GoodJob.retry_on_unhandled_error = true
GoodJob.on_thread_error = ->(exception) { GayFurCity::Logger.log(exception, source: "GoodJob") }
