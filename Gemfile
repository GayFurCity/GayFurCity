# frozen_string_literal: true

source("https://rubygems.org/")

gem("dotenv", require: "dotenv/load")

gem("rails", "~> 8.0.0")
gem("pg")
gem("dalli", platforms: :ruby)
gem("simple_form")
gem("ruby-vips")
gem("bcrypt", require: "bcrypt")
gem("draper")
gem("streamio-ffmpeg")
gem("responders")
# gem "dtext_rb", git: "https://github.com/GayFurCity/dtext_rb.git", branch: "master", require: "dtext"
gem("dtext_rb", require: "dtext")
gem("bootsnap")
gem("addressable")
gem("recaptcha", require: "recaptcha/rails")
gem("webpacker", ">= 4.0.x")
gem("retriable")
gem("good_job")
gem("marcel")
gem("redis")
gem("request_store")

gem("diffy")
gem("rugged")

gem("elasticsearch", "~> 8.18.0")

gem("mailgun-ruby")

gem("faraday")
gem("faraday-follow_redirects")
gem("faraday-retry")

gem("prometheus-client")
gem("yabeda")
gem("yabeda-rails")
gem("yabeda-prometheus")
gem("yabeda-activerecord")
gem("yabeda-gc")
gem("yabeda-http_requests")
gem("yabeda-latency")

group(:production) do
  gem("pitchfork")
end

group(:development) do
  gem("puma")
  gem("yabeda-puma-plugin")
  gem("debug", require: false)
  gem("rubocop", require: false)
  gem("rubocop-erb", require: false)
  gem("rubocop-rails", require: false)
  gem("rubocop-faker", require: false)
  gem("rubocop-minitest", require: false)
  gem("rubocop-rake", require: false)
  gem("rubocop-factory_bot", require: false)
  gem("rubocop-yiffspace", require: false)
  gem("rubocop-performance", require: false)
  gem("rexml", ">= 3.3.6")
  gem("ruby-lsp")
  gem("ruby-lsp-rails", "~> 0.3.13")
  gem("faker", require: false)
  gem("bullet")
  gem("active_record_query_trace")
  gem("rack-mini-profiler")
  gem("memory_profiler")
  gem("stackprof")
  gem("brakeman", "~> 8.0", require: false)
end

group(:test) do
  gem("shoulda-context", require: false)
  gem("shoulda-matchers", require: false)
  gem("factory_bot_rails", require: false)
  gem("mocha", require: false)
  gem("webmock", require: false)
  gem("simplecov", require: false)
  gem("simplecov-cobertura", require: false)
  gem("minitest-reporters", require: false)
  gem("redis-namespace", require: false)
end

gem("pundit", "~> 2.3")
gem("net-ftp", "~> 0.3.4")
gem("rakismet", "~> 1.5")
gem("jwt", "~> 2.8")
gem("rotp", "~> 6.3")
gem("rqrcode", "~> 2.2")
gem("click_house", "~> 2.1")
gem("after_commit_everywhere", "~> 1.6")
gem("active_record_extended", "~> 3.3")
# https://github.com/rails/rails/issues/49259, https://github.com/ruby/irb/pull/916#discussion_r1553958795
gem("irb", "~> 1.15.2")

gem("recursive-open-struct", "~> 2.0")

gem("csv", "~> 3.3")

gem("abbrev", "~> 0.1.2")

gem("concurrent-ruby", "~> 1.3")

gem("builder", "~> 3.3")

gem("image_processing", "~> 1.14")

gem("yiffspace", "~> 0.1.3")
gem("yiffspace-auth", "~> 0.0.3")

# XXX: Added to silence "loaded from standard library" warnings
gem("benchmark", "~> 0.5.0")
gem("fiddle", "~> 1.1")
