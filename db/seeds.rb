# frozen_string_literal: true

require("digest/md5")
require("tempfile")
require("net/http")
require_relative("seeds/post_deletion_reasons")
require_relative("seeds/post_replacement_rejection_reasons")
require_relative("seeds/posts")

# Uncomment to see detailed logs
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)

module Seeds
  def self.run!(user = User.system)
    Seeds::Posts.run!(user)
    Mascots.run!(user)
  end

  def self.create_aibur_category!(user = User.system)
    ForumCategory.find_or_create_by!(name: "Tag Alias and Implication Suggestions") do |category|
      category.can_view = 0
      category.creator = user
    end
  end

  def self.api_request(path)
    puts("-> GET #{base_url}#{path}")
    response = Faraday.get("#{base_url}#{path}", nil, user_agent: "gayfurcity/seeding")
    JSON.parse(response.body)
  end

  def self.base_url
    read_resources["base_url"]
  end

  def self.e621?
    base_url.include?("e621.net")
  end

  def self.read_resources
    if @resources
      yield(@resources) if block_given?
      return @resources
    end
    @resources = YAML.load_file(Rails.root.join("db/seeds.yml"))
    @resources["tags"] << "randseed:#{Digest::MD5.hexdigest(Time.now.to_s)}" if @resources["tags"]&.include?("order:random")
    yield(@resources) if block_given?
    @resources
  end

  def self.log(...)
    puts(...)
  end

  class Mascots
    def self.run!(user = User.system)
      new(user).run!
    end

    attr_reader(:user)

    def initialize(user)
      @user = user.resolvable
    end

    def run!
      Seeds.read_resources do |resources|
        if resources["mascots"].empty?
          create_from_web
        else
          create_from_local
        end
      end
    end

    def create_from_web
      Seeds.api_request("/mascots.json").each do |mascot|
        next if Mascot.exists?(display_name: mascot["display_name"])
        url = Seeds.e621? ? mascot["url_path"] : mascot["file_url"]
        puts(url)
        Mascot.find_or_create_by!(display_name: mascot["display_name"]) do |masc|
          masc.file = Downloads::File.new(url, user: user).download!
          masc.background_color = mascot["background_color"]
          masc.artist_url = mascot["artist_url"]
          masc.artist_name = mascot["artist_name"]
          masc.available_on_string = Config.instance.app_name
          masc.hide_anonymous = mascot["hide_anonymous"]
          masc.active = mascot["active"]
          masc.creator = user
        end
      end
    end

    def create_from_local
      resources = Seeds.read_resources
      resources["mascots"].each do |mascot|
        next if ::Mascot.exists?(display_name: mascot["name"])
        puts(mascot["file"])
        Mascot.find_or_create_by!(display_name: mascot["name"]) do |masc|
          masc.file = Downloads::File.new(mascot["file"], user: user).download!
          masc.background_color = mascot["color"]
          masc.artist_url = mascot["artist_url"]
          masc.artist_name = mascot["artist_name"]
          masc.available_on_string = Config.instance.app_name
          masc.active = mascot["active"]
          masc.hide_anonymous = mascot["hide_anonymous"]
          masc.creator = user
        end
      end
    end
  end
end

USER = User.system
if ENV.fetch("POSTS_ONLY", false).to_s.truthy?
  Seeds::Posts.run!(USER)
else
  ModAction.without_logging do
    Seeds.create_aibur_category!(USER)
    PostDeletionReasons.run!(USER)
    PostReplacementRejectionReasons.run!(USER)

    unless Rails.env.test?
      Seeds.run!(USER)
    end
  end
end
