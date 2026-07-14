# frozen_string_literal: true

require("test_helper")

class StorageManagerTest < ActiveSupport::TestCase
  # A method (not a class constant) so Process.pid is read per-test in the actual worker process,
  # not once at class-load time in the primary process before `parallelize` forks - otherwise every
  # worker would share the same directory and race on creating/reading/deleting the same files.
  def base_dir
    @base_dir ||= Rails.root.join("tmp/test-storage-p#{Process.pid}-#{object_id}").to_s
  end

  context("StorageManager::Local") do
    setup do
      @base_url = "http://localhost"
      @storage_manager = StorageManager::Local.new(base_dir: base_dir, base_url: @base_url)
    end

    teardown do
      FileUtils.rm_rf(base_dir)
    end

    context("#store method") do
      should("store the file") do
        @storage_manager.store(StringIO.new("data"), "#{base_dir}/test.txt")

        assert_equal("data", File.read("#{base_dir}/test.txt"))
      end

      should("overwrite the file if it already exists") do
        @storage_manager.store(StringIO.new("foo"), "#{base_dir}/test.txt")
        @storage_manager.store(StringIO.new("bar"), "#{base_dir}/test.txt")

        assert_equal("bar", File.read("#{base_dir}/test.txt"))
      end
    end

    context("#delete method") do
      should("delete the file") do
        @storage_manager.store(StringIO.new("data"), "#{base_dir}/test.txt")
        @storage_manager.delete("#{base_dir}/test.txt")

        assert_not(File.exist?("#{base_dir}/test.txt"))
      end

      should("not fail if the file doesn't exist") do
        assert_nothing_raised { @storage_manager.delete("#{base_dir}/dne.txt") }
      end
    end

    context("#file_name method") do
      should("return the correct name") do
        md5 = SecureRandom.hex(16)
        format = ->(ext, type) { @storage_manager.file_name(md5, ext, type) }

        assert_equal("#{md5}.webm", format.call("webm", :original))
        assert_equal("#{md5}.webp", format.call("webp", :crop))
        assert_equal("#{md5}.webp", format.call("webp", :large))
        assert_equal("#{md5}.webp", format.call("webp", :preview))
        assert_equal("#{md5}.webm", format.call("webm", :"720p"))
        assert_equal("#{md5}.mp4", format.call("mp4", :"720p"))
        assert_equal("#{md5}.webm", format.call("webm", :"480p"))
        assert_equal("#{md5}.mp4", format.call("mp4", :"480p"))
      end
    end

    context("#url method") do
      should("return the correct urls") do
        md5 = SecureRandom.hex(16)
        format = ->(ext, type) { @storage_manager.url(md5, ext, type, protected: false, prefix: GayFurCity.config.post_path_prefix, protected_prefix: GayFurCity.config.protected_path_prefix) }

        assert_equal("#{@base_url}/data/posts/#{md5}.webm", format.call("webm", :original))
        assert_equal("#{@base_url}/data/posts/crop/#{md5}.webp", format.call("webp", :crop))
        assert_equal("#{@base_url}/data/posts/large/#{md5}.webp", format.call("webp", :large))
        assert_equal("#{@base_url}/data/posts/preview/#{md5}.webp", format.call("webp", :preview))
        assert_equal("#{@base_url}/data/posts/720p/#{md5}.webm", format.call("webm", :"720p"))
        assert_equal("#{@base_url}/data/posts/720p/#{md5}.mp4", format.call("mp4", :"720p"))
        assert_equal("#{@base_url}/data/posts/480p/#{md5}.webm", format.call("webm", :"480p"))
        assert_equal("#{@base_url}/data/posts/480p/#{md5}.mp4", format.call("mp4", :"480p"))
      end
    end

    context("#url_path method") do
      should("return the correct paths") do
        md5 = SecureRandom.hex(16)
        format = ->(ext, type) { @storage_manager.url_path(md5, ext, type, protected: false, prefix: GayFurCity.config.post_path_prefix, protected_prefix: GayFurCity.config.protected_path_prefix) }

        assert_equal("/data/posts/#{md5}.webm", format.call("webm", :original))
        assert_equal("/data/posts/crop/#{md5}.webp", format.call("webp", :crop))
        assert_equal("/data/posts/large/#{md5}.webp", format.call("webp", :large))
        assert_equal("/data/posts/preview/#{md5}.webp", format.call("webp", :preview))
        assert_equal("/data/posts/720p/#{md5}.webm", format.call("webm", :"720p"))
        assert_equal("/data/posts/720p/#{md5}.mp4", format.call("mp4", :"720p"))
        assert_equal("/data/posts/480p/#{md5}.webm", format.call("webm", :"480p"))
        assert_equal("/data/posts/480p/#{md5}.mp4", format.call("mp4", :"480p"))
      end
    end

    context("#file_path method") do
      should("return the correct paths") do
        md5 = SecureRandom.hex(16)
        format = ->(ext, type) { @storage_manager.file_path(md5, ext, type, protected: false, prefix: GayFurCity.config.post_path_prefix, protected_prefix: GayFurCity.config.protected_path_prefix) }

        assert_equal("#{base_dir}/posts/#{md5}.webm", format.call("webm", :original))
        assert_equal("#{base_dir}/posts/crop/#{md5}.webp", format.call("webp", :crop))
        assert_equal("#{base_dir}/posts/large/#{md5}.webp", format.call("webp", :large))
        assert_equal("#{base_dir}/posts/preview/#{md5}.webp", format.call("webp", :preview))
        assert_equal("#{base_dir}/posts/720p/#{md5}.webm", format.call("webm", :"720p"))
        assert_equal("#{base_dir}/posts/720p/#{md5}.mp4", format.call("mp4", :"720p"))
        assert_equal("#{base_dir}/posts/480p/#{md5}.webm", format.call("webm", :"480p"))
        assert_equal("#{base_dir}/posts/480p/#{md5}.mp4", format.call("mp4", :"480p"))
      end
    end
  end
end
