# frozen_string_literal: true

module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      klass.attr_accessor(:skip_index_update)

      # In test, suffix with -p<pid> (and -n<TEST_ENV_NUMBER>, set by Rails' thread-based parallel
      # test workers, when present) so concurrent test runs - separate `bin/rails test` invocations,
      # or parallel workers within one - each get their own index instead of racing on a shared one.
      # The p/n-prefixed format makes it obvious at a glance in logs what a given index/db name is
      # (see also test/support/isolated_database.rb, which names test databases the same way).
      # Never suffix outside test: dev/production need a stable index name across restarts.
      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}#{"-p#{Process.pid}#{"-n#{ENV['TEST_ENV_NUMBER']}" if ENV['TEST_ENV_NUMBER'].present?}" if Rails.env.test?}"

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
