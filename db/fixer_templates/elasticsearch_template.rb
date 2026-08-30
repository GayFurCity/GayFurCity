# frozen_string_literal: true

# `bin/rails generate yiffspace:fixer name_of_change -e` (or --template elasticsearch) scaffolds
# the two-step index+data pattern used whenever a field is added to/changed in an ES mapping.
class ElasticsearchTemplate < YiffSpace::FixerTemplate
  short("e")

  step do
    <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

      client = Post.document_store.client
      client.indices.put_mapping(index: Post.document_store.index_name, body: { properties: { FIELD_NAME: { type: "TYPE" } } })
    RUBY
  end

  step do
    <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

      client = Post.document_store.client
      Post.find_in_batches(batch_size: 10_000) do |posts|
        client.bulk(body: posts.map { |post| { update: { _index: Post.document_store.index_name, _id: post.id, data: { doc: { FIELD_NAME: post.FIELD_NAME } } } } }, refresh: true)
      end
    RUBY
  end
end
