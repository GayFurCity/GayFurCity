#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

puts("Reindexing ElasticSearch Posts")
Post.document_store.import
