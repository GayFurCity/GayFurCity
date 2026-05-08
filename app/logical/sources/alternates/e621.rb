# frozen_string_literal: true

module Sources
  module Alternates
    class E621 < Base
      IMAGE_MD5 = %r{static\d\.(?:e621|e926)\.net/data/[a-z\d]{2}/[a-z\d]{2}/([a-z\d]{32})}

      def force_https?
        true
      end

      def domains
        %w[e621.net e926.net]
      end

      def parse
        # Add post link, parsed from direct link
        if @url =~ IMAGE_MD5
          id = get_post_by_md5($1)
          if id
            @submission_url = "https://e621.net/posts/#{id}"
            @direct_url = @url.gsub("e926.net", "e621.net")
          end
        end
      end

      def original_url
        # Remove comment anchor
        if @parsed_url.fragment&.start_with?("comment_")
          @parsed_url.fragment = nil
        end

        @url = @parsed_url.to_s.gsub("e926.net", "e621.net")
      end

      private

      def get_post_by_md5(md5)
        Cache.fetch("e6md5:#{md5}", expires_in: 1.day) do
          response = Faraday.new(GayFurCity.config.faraday_options).get("https://e621.net/posts.json?md5=#{md5}")
          JSON.parse(response.body).dig("post", "id")
        end
      end
    end
  end
end
