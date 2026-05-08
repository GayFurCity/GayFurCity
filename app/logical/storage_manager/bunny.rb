# frozen_string_literal: true

require("net/ftp")

module StorageManager
  class Bunny < StorageManager::Ftp
    attr_reader(:api_key)

    def initialize(host:, port:, username:, password:, api_key:, **)
      super(host: host, port: port, username: username, password: password, **)
      @api_key = api_key
    end

    def protected_params(url, secret: nil, user: nil)
      raise(ArgumentError, "user is required for protected_params") if user.blank?
      user_id = user.id
      time = (Time.now + 15.minutes).to_i
      hash = Digest::SHA2.base64digest("#{secret}#{url}#{time}token_path=#{url}&user=#{user_id}")
                         .tr("+", "-").tr("/", "_").tr("=", "")
      "?token=#{hash}&token_path=#{URI.encode_uri_component(url)}&expires=#{time}&user=#{user_id}"
    end

    def purge_cache(url)
      conn = Faraday.new(GayFurCity.config.faraday_options) do |r|
        r.headers["AccessKey"] = api_key
      end
      conn.post("https://api.bunny.net/purge?async=false&url=#{CGI.escape(url)}").success?
    end

    def delete(path)
      log(%{delete("#{path}")}) do
        super
        purge_cache("#{base_url}#{path}")
      end
    end
  end
end
