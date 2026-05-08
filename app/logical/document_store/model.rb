# frozen_string_literal: true

module DocumentStore
  module Model
    def self.included(klass)
      klass.include(Proxy)

      klass.attr_accessor(:skip_index_update)

      klass.document_store.index_name = "#{klass.model_name.plural}_#{Rails.env}"

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
