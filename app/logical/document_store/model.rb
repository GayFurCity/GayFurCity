# frozen_string_literal: true

module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      klass.attr_writer(:skip_index_update)

      # Defaults to true in test: most tests never touch search, but every write here forces a
      # synchronous, refresh:true round trip to Elasticsearch (see #update_index) since jobs don't
      # run under Sidekiq::Testing.fake!. Tests that DO care about search opt back in via
      # TestHelpers::Util#reset_post_index, which flips this back to false for their duration.
      klass.define_method(:skip_index_update) do
        return @skip_index_update unless @skip_index_update.nil?
        Rails.env.test?
      end

      # In test, suffix with -p<pid> so separate `bin/rails test` invocations each get their own
      # index instead of racing on a shared one. test_helper.rb further suffixes this with
      # -n<worker number> per Rails `parallelize` worker process (see its after_fork hook), since
      # each worker inherits this same pid-based name from before it forked. The p/n-prefixed format
      # makes it obvious at a glance in logs what a given index/db name is (see also
      # test/support/isolated_database.rb, which names test databases the same way). Never suffix
      # outside test: dev/production need a stable index name across restarts.
      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}#{"-p#{Process.pid}" if Rails.env.test?}"

      klass.after_commit(on: %i[create], unless: :skip_index_update) do
        document_store.update_index(refresh: Rails.env.test?.to_s)
      end

      klass.after_commit(on: %i[update], unless: :skip_index_update) do
        update_index
      end

      klass.after_commit(on: %i[destroy], unless: :skip_index_update) do
        document_store.delete_document(refresh: Rails.env.test?.to_s)
      end
    end

    def update_index(queue: :high)
      # TODO: race condition hack, makes tests SLOW!!!
      return document_store.update_index(refresh: "true") if Rails.env.test?

      IndexUpdateJob.set(queue: queue).perform_later(self.class.to_s, id)
    end
  end

  def self.client
    @client ||= Elasticsearch::Client.new(host: GayFurCity.config.elasticsearch_host, request_timeout: 120)
  end
end
