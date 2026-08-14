# frozen_string_literal: true

module PostVersionIndex
  def self.included(base)
    base.document_store.index = {
      settings: {
        index: {
          number_of_shards:   ENV.fetch("GAYFURCITY_ELASTICSEARCH_POSTVERSION_INDEX_SHARDS", 8).to_i,
          number_of_replicas: ENV.fetch("GAYFURCITY_ELASTICSEARCH_POSTVERSION_INDEX_REPLICAS", 0).to_i,
          max_result_window:  ENV["GAYFURCITY_ELASTICSEARCH_POSTVERSION_INDEX_RESULTS"]&.to_i,
        }.compact,
      },
      mappings: {
        dynamic:    false,
        properties: {
          id:                  { type: "integer" },
          post_id:             { type: "integer" },
          version:             { type: "integer" },
          updater_id:          { type: "integer" },
          parent_id:           { type: "integer" },
          rating:              { type: "keyword" },
          source:              { type: "keyword" },
          description:         { type: "text" },
          reason:              { type: "text" },

          description_changed: { type: "boolean" },
          parent_id_changed:   { type: "boolean" },
          source_changed:      { type: "boolean" },
          rating_changed:      { type: "boolean" },

          tags_added:          { type: "keyword" },
          tags_removed:        { type: "keyword" },
          tags:                { type: "keyword" },

          updated_at:          { type: "date" },

          locked_tags_added:   { type: "keyword" },
          locked_tags_removed: { type: "keyword" },
          locked_tags:         { type: "keyword" },
        },
      },
    }

    base.document_store.extend(ClassMethods)
  end

  module ClassMethods
    def import(options = {})
      q = all
      q = q.where(id: (options[:from])..) if options[:from]
      q = q.where(id: ..(options[:to])) if options[:to]
      q = q.where(options[:query]) if options[:query]
      q.find_in_batches(batch_size: 10_000) do |batch|
        batch.map! do |pv|
          {
            index: {
              _id:  pv.id,
              data: pv.as_indexed_json,
            },
          }
        end

        client.bulk({
          index: index_name,
          body:  batch,
        })
      end
    end
  end

  def as_indexed_json(_options = {})
    {
      id:                  id,
      post_id:             post_id,
      updated_at:          updated_at,
      version:             version,
      updater_id:          updater_id,
      parent_id:           parent_id,
      rating:              rating,
      source:              source,
      description:         description,
      reason:              reason,

      description_changed: description_changed,
      parent_id_changed:   parent_changed,
      source_changed:      source_changed,
      rating_changed:      rating_changed,

      tags_added:          added_tags,
      tags_removed:        removed_tags,
      tags:                tag_array,

      locked_tags_added:   added_locked_tags,
      locked_tags_removed: removed_locked_tags,
      locked_tags:         locked_tag_array,
    }
  end
end
