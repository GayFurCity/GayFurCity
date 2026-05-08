# frozen_string_literal: true

module Reports
  module_function

  LIMIT = 100

  def enabled?
    !Rails.env.test? && GayFurCity.config.reports.enabled?
  end

  def request(method, path, body = nil)
    conn = Faraday.new(GayFurCity.config.faraday_options.deep_merge(headers: { authorization: "Bearer #{jwt_signature(path)}", content_type: "application/json" })) do |c|
      c.use(Faraday::Response::RaiseError)
    end
    response = conn.public_send(method, "#{GayFurCity.config.reports.server_internal}#{path}", body&.to_json)
    JSON.parse(response.body)
  end

  def get(path)
    request(:get, path)
  end

  def post(path, body)
    request(:post, path, body)
  end

  # Hash { "viewCount" => 0, "searchCount" => 0, "missedSearchCount" => 0, "schemaVersion" => 0, "dbVersion" => "", "healthy" => true, "error" => nil }[]
  def get_stats
    unless enabled?
      return {
        "viewCount"         => 0,
        "searchCount"       => 0,
        "missedSearchCount" => 0,
        "schemaVersion"     => 0,
        "dbVersion"         => "NONE",
        "healthy"           => true,
        "error"             => nil,
      }
    end
    Cache.fetch("reports-stats", expires_in: 1.minute) do
      get("/stats")
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    log = ExceptionLog.add!(e, source: "Reports#get_stats", args: get_arguments(binding))
    {
      "viewCount"         => 0,
      "searchCount"       => 0,
      "missedSearchCount" => 0,
      "schemaVersion"     => 0,
      "dbVersion"         => "NONE",
      "healthy"           => false,
      "error"             => "Request Failed: #{log.code}",
    }
  end

  def get_post_views(post_id, date: nil, unique: false)
    return 0 unless enabled?
    d = date&.strftime("%Y-%m-%d")
    q = { date: d, unique: unique }.compact_blank.to_query
    Cache.fetch("pv-#{post_id}-#{d || 'all'}-#{unique}", expires_in: 1.minute) do
      get("/views/#{post_id}?#{q}")["data"].to_i
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_post_views", args: get_arguments(binding))
    0
  end

  # Hash { "post" => 0, "count" => 0 }[]
  def get_post_views_rank(date, limit: LIMIT, unique: false)
    return [] unless enabled?
    d = date.strftime("%Y-%m-%d")
    q = { date: d, limit: limit, unique: unique }.compact_blank.to_query
    Cache.fetch("pv-rank-#{d}-#{unique}", expires_in: 1.minute) do
      get("/views/rank?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_post_views_rank", args: get_arguments(binding))
    []
  end

  # Hash { "post" => 0, "count" => 0 }[]
  def get_top_post_views(limit: LIMIT, unique: false)
    return [] unless enabled?
    q = { limit: limit, unique: unique }.compact_blank.to_query
    Cache.fetch("pv-top", expires_in: 1.minute) do
      get("/views/top?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_top_post_views", args: get_arguments(binding))
    []
  end

  # Hash { "tag" => "name", "count" => 0 }[]
  def get_post_searches_rank(date, limit: LIMIT)
    return [] unless enabled?
    d = date.strftime("%Y-%m-%d")
    q = { date: d, limit: limit }.compact_blank.to_query
    Cache.fetch("ps-rank-#{d}", expires_in: 1.minute) do
      get("/searches/rank?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_post_searches_rank", args: get_arguments(binding))
    []
  end

  # Hash { "tag" => "name", "count" => 0 }[]
  def get_top_post_searches(limit: LIMIT)
    return [] unless enabled?
    q = { limit: limit }.compact_blank.to_query
    Cache.fetch("ps-top", expires_in: 1.minute) do
      get("/searches/top?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_top_post_searches", args: get_arguments(binding))
    []
  end

  # Hash { "tag" => "name", "count" => 0 }[]
  def get_missed_searches_rank(date, limit: LIMIT)
    return [] unless enabled?
    d = date.strftime("%Y-%m-%d")
    q = { date: d, limit: limit }.compact_blank.to_query
    Cache.fetch("ms-rank-#{d}", expires_in: 1.minute) do
      get("/searches/missed/rank?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_missed_searches_rank", args: get_arguments(binding))
    []
  end

  # Hash { "tag" => "name", "count" => 0 }[]
  def get_top_missed_searches(limit: LIMIT)
    return [] unless enabled?
    q = { limit: limit }.compact_blank.to_query
    Cache.fetch("ms-top", expires_in: 1.minute) do
      get("/searches/missed/top?#{q}")["data"]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_top_missed_searches", args: get_arguments(binding))
    []
  end

  # Hash { post_id => count }
  def get_bulk_post_views(post_ids, date: nil, unique: false)
    return {} unless enabled?
    d = date&.strftime("%Y-%m-%d")
    post_ids.each_slice(100).flat_map do |ids|
      q = { date: d, unique: unique, posts: ids.join(",") }.compact_blank.to_query
      get("/views/bulk?#{q}")["data"]
    end.compact_blank.to_h { |x| [x["post"], x["count"]] }
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_bulk_post_views", args: get_arguments(binding))
    {}
  end

  def log_api_key_usage(key_id, controller, action, method, request_uri, ip_address)
    return false unless enabled?
    post("/api_key_usages", { msg: generate_body_signature(purpose: "api-key-usages", ip_address: ip_address, key_id: key_id, action: action, controller: controller, method: method, request_uri: request_uri) })
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#log_api_key_usage", args: get_arguments(binding))
    false
  end

  # Hash { "action" => "show",  "controller" => "posts", "date" => "0000-00-00", "ip_address" => "127.0.0.1", "method" => "GET", "request_uri" => "/posts/1.json" }[]
  # @return [UsageData]
  def get_api_key_usages(key_id, date: nil, limit: LIMIT, page: 1)
    return UsageData.new(0, []) unless enabled?
    page += 1 if page == 0
    d = date&.strftime("%Y-%m-%d")
    q = { date: d, limit: limit, page: page }.compact_blank.to_query
    r = get("/api_key_usages/#{key_id}?#{q}")
    data = r["data"].each_with_object([]) do |x, arr|
      arr << ApiKeyUsage.new(*x.transform_keys(&:to_sym).values_at(*ApiKeyUsage.members))
    end
    UsageData.new(r["count"], data)
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError => e
    ExceptionLog.add!(e, source: "Reports#get_api_key_usages", args: get_arguments(binding))
    UsageData.new(0, [])
  end

  def jwt_signature(url)
    JWT.encode({
      iss: "GayFurCity",
      iat: Time.now.to_i,
      exp: 1.minute.from_now.to_i,
      aud: "Reports",
      sub: url.split("?").first,
    }, GayFurCity.config.report_key, "HS256")
  end

  def generate_body_signature(purpose:, ip_address:, **values)
    verifier = ActiveSupport::MessageVerifier.new(GayFurCity.config.report_key, serializer: JSON, digest: "SHA256")
    verifier.generate({ ip_address: ip_address, **values }, purpose: purpose)
  end

  def get_arguments(binding)
    method(caller_locations(2, 1)[0].label).parameters.to_h do |_, name|
      [name, binding.local_variable_get(name)]
    end
  end

  PostView = Struct.new(:id, :post_id, :ip_address, :date)
  MissedSearch = Struct.new(:id, :tags, :page, :date)
  Search = Struct.new(:id, :tags, :page, :date)
  ApiKeyUsage = Struct.new(:action, :controller, :date, :ip_address, :method, :request_uri)

  # @member count [Integer]
  # @member data [Array(ApiKeyUsage)]
  UsageData = Struct.new(:count, :data)

  def get_all_post_views
    ClickHouse.connection.select_all("SELECT post_id, COUNT(*) as count FROM post_views GROUP BY (post_id)").to_h { |v| [v["post_id"], v["count"]] }
  end

  def get_views_for_posts(post_ids)
    ClickHouse.connection.select_all("SELECT post_id, COUNT(*) as count FROM post_views WHERE post_id IN (#{post_ids.join(', ')}) GROUP BY (post_id)").to_h { |v| [v["post_id"], v["count"]] }
  end
end
