# frozen_string_literal: true

module ErisProxy
  class Error < StandardError; end
  class BusyError < Error; end
  class CircuitOpenError < Error; end

  ERIS_NUM_PIXELS = 128

  CIRCUIT_FAILURES_KEY = "eris:circuit:failures"
  CIRCUIT_OPEN_KEY = "eris:circuit:open"
  ANON_LOCKDOWN_KEY = "eris:anon:lockdown"
  CONCURRENT_KEY = "eris:concurrent"

  # Sets the expiry only on the first increment, giving a fixed window counter
  INCR_WITH_EXPIRY = <<~LUA
    local v = redis.call('incr', KEYS[1])
    if v == 1 then redis.call('expire', KEYS[1], ARGV[1]) end
    return v
  LUA

  # Floors at zero so a counter that expired mid-request doesn't go negative
  DECR_FLOOR_ZERO = <<~LUA
    local v = redis.call('decr', KEYS[1])
    if v < 0 then redis.call('set', KEYS[1], '0') end
    return v
  LUA

  module_function

  def endpoint
    GayFurCity.config.eris_server
  end

  def enabled?
    endpoint.present?
  end

  def make_request(path, request_type, body = nil)
    conn = Faraday.new(GayFurCity.config.faraday_options.deep_merge(request: { timeout: GayFurCity.config.eris_read_timeout }))
    headers = { content_type: "application/json" }
    headers[:authorization] = "Bearer #{GayFurCity.config.eris_token}" if GayFurCity.config.eris_token.present?
    conn.send(request_type, endpoint + path, body&.to_json, headers)
  rescue Faraday::Error
    raise(Error, "This service is temporarily unavailable. Please try again later.")
  end

  def update_post(post)
    return unless post.has_preview?

    thumb = nil
    post.preview_file do |file|
      thumb = generate_thumbnail(file.path)
    end
    raise(Error, "failed to generate thumb for #{post.id}") unless thumb

    response = make_request("/images/#{post.id}", :post, get_channels_data(thumb))
    raise(Error, "eris request failed") if response.status != 200
  end

  def remove_post(post_id)
    response = make_request("/images/#{post_id}", :delete)
    raise(Error, "eris request failed") if response.status != 200
  end

  def query_url(user, image_url, score_cutoff)
    # A dead host should only cost one timeout while the user is holding a throttle slot
    file = Downloads::File.new(image_url, user: user).download!(retries: 0)
    query_file(file, score_cutoff)
  end

  def query_post(post_id, score_cutoff)
    post_id = post_id.to_i
    return [] if post_id <= 0

    query({ post_id: post_id }, score_cutoff)
  end

  def query_file(file, score_cutoff)
    thumb = generate_thumbnail(file.path)
    return [] unless thumb

    query(get_channels_data(thumb), score_cutoff)
  end

  def query_hash(hash, score_cutoff)
    query({ hash: hash }, score_cutoff)
  end

  def query(body, score_cutoff)
    check_circuit!
    with_query_semaphore do
      response = record_circuit_outcome { make_request("/query", :post, body) }
      return [] if response.status != 200

      process_eris_result(JSON.parse(response.body), score_cutoff)
    end
  end

  def process_eris_result(json, score_cutoff)
    raise(Error, "Server returned an error. Most likely the url is not found.") unless json.is_a?(Array)

    json.filter! { |entry| (entry["score"] || 0) >= (score_cutoff.presence || 60).to_i }
    posts = Post.where(id: json.pluck("post_id").compact).index_by(&:id)
    json.filter_map do |x|
      x["post"] = posts[x["post_id"]]
      x if x["post"]
    end
  end

  def generate_thumbnail(file_path)
    Vips::Image.thumbnail(file_path, ERIS_NUM_PIXELS, height: ERIS_NUM_PIXELS, size: :force)
  rescue Vips::Error => e
    ExceptionLog.add!(e, source: "ErisProxy#generate_thumbnail")
    Rails.logger.error("failed to generate thumbnail for #{file_path}")
    Rails.logger.error(e)
    nil
  end

  def get_channels_data(thumbnail)
    r = []
    g = []
    b = []
    is_grayscale = thumbnail.bands == 1
    thumbnail.to_a.each do |data|
      data.each do |rgb|
        r << rgb[0]
        g << (is_grayscale ? rgb[0] : rgb[1])
        b << (is_grayscale ? rgb[0] : rgb[2])
      end
    end
    { channels: { r: r, g: g, b: b } }
  end

  def anon_lockdown?
    Cache.redis.exists?(ANON_LOCKDOWN_KEY)
  end

  def check_circuit!
    raise(CircuitOpenError, "Similar image search is temporarily unavailable. Please try again later.") if Cache.redis.exists?(CIRCUIT_OPEN_KEY)
  end

  def record_circuit_outcome
    response = yield
    record_circuit_failure if response.status >= 500
    response
  rescue Error
    record_circuit_failure
    raise
  end

  def record_circuit_failure
    count = Cache.redis.eval(INCR_WITH_EXPIRY, keys: [CIRCUIT_FAILURES_KEY], argv: [GayFurCity.config.eris_circuit_failure_window])
    open_circuit! if count >= GayFurCity.config.eris_circuit_failure_threshold
  end

  def open_circuit!
    cooldown = GayFurCity.config.eris_circuit_cooldown
    return unless Cache.redis.set(CIRCUIT_OPEN_KEY, Time.now.to_i, ex: cooldown, nx: true)

    Cache.redis.del(CIRCUIT_FAILURES_KEY)
    Cache.redis.set(ANON_LOCKDOWN_KEY, Time.now.to_i, ex: GayFurCity.config.eris_anon_lockdown_duration)
    Rails.logger.warn("ErisProxy: circuit opened, cooling down for #{cooldown}s and locking out anonymous users for #{GayFurCity.config.eris_anon_lockdown_duration}s")
  end

  def with_query_semaphore
    # The expiry clears out counts leaked by processes that died mid-query
    count = Cache.redis.eval(INCR_WITH_EXPIRY, keys: [CONCURRENT_KEY], argv: [GayFurCity.config.eris_read_timeout * 10])
    if count > GayFurCity.config.eris_max_concurrent_queries
      Cache.redis.eval(DECR_FLOOR_ZERO, keys: [CONCURRENT_KEY])
      raise(BusyError, "Similar image search is busy. Please try again later.")
    end

    begin
      yield
    ensure
      Cache.redis.eval(DECR_FLOOR_ZERO, keys: [CONCURRENT_KEY])
    end
  end

  private_class_method(:query, :check_circuit!, :record_circuit_outcome, :record_circuit_failure, :open_circuit!, :with_query_semaphore)
end
