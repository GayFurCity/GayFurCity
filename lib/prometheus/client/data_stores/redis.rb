# frozen_string_literal: true

require("cgi")
require("uri")

# Copied from https://github.com/wearemolecule/prometheus-client-data_stores-redis/tree/2fc4cbc12380fd349f6a4dbb01886bebfe3948fc with minor adaptations
module Prometheus
  module Client
    module DataStores
      # Stores data in Redis, as a simple way of getting a shared piece of memory between
      # processes.
      # This store is useful to deal with pre-fork servers and other "multi-process"
      # scenarios where processes need to have access to each other's metrics data.
      #
      # IMPORTANT NOTE!!! You must have a local Redis server in each of your boxes where
      # you run this store.
      # Do not use a shared Redis server for all your servers. On the one hand, the network
      # roundtrip is going to be outrageously slow, and on the other, metrics between
      # your different servers would get conflated into one, giving invalid results.
      #
      # If you can't have each box have their own local Redis server, you may want to use
      # Pstore instead.
      #
      # Alternatively, if a shared Redis box is the only possible option for some reason,
      # and you're willing to accept the performance hit from it, you'd need to modify this
      # store to add a "server_id" to the keys stored in Redis, and somehow set that prefix
      # to be unique to each server. Or something similar to that. Make sure to benchmark
      # this against the Pstore to make sure it's actually the best route.
      #
      # It's also important to note that Redis is somewhat lossy when it comes to tiny
      # floats. The `spec/prometheus/client/formats/text_spec.rb` test fails if set to use
      # this store, because it sets `1.23e-45` as a value for a counter, and Redis
      # returns 0. This is documented in Redis, it only outputs 17 digits of precision
      # (https://redis.io/commands/incrbyfloat).
      # In most cases this should not be a problem, but if your metrics include tiny floats,
      # this store won't work as-is.
      #
      # When exporting metrics, the process that gets scraped by Prometheus will get the
      # values for each process, and aggregate them (generally that means SUMming the
      # values for each labelset).
      #
      # In order to do this, each Metric needs an `:aggregation` setting, specifying how
      # to aggregate the multiple possible values we can get for each labelset. By default,
      # they are `SUM`med, which is what most use cases call for (counters and histograms,
      # for example).
      # However, for Gauges, it's possible to set `MAX` or `MIN` as aggregation, to get
      # the highest value of all the processes / threads.
      #
      # When storing values in Redis, each process will have their own key. While it would
      # be great to just have one key for all processes, and take advantage of INCR to
      # always have the total value, which would be perfect for Counters and Histograms,
      # we still need to keep separate values for Gauges, to be able to compute the MAX/MIN
      # if that's what the user needs.
      #
      # The code could be modified so that this extra label is only added if the aggregation
      # mode is not SUM. However, this makes the code more complex for little actual gain.
      class Redis
        class InvalidStoreSettingsError < StandardError; end
        AGGREGATION_MODES = [MAX = :max, MIN = :min, SUM = :sum, MOST_RECENT = :most_recent].freeze
        DEFAULT_METRIC_SETTINGS = { aggregation: SUM }.freeze

        def initialize(connection_pool:)
          @connection_pool = connection_pool
        end

        # noinspection RubyUnusedLocalVariable
        def for_metric(metric_name, metric_type:, metric_settings: {}) # rubocop:disable Lint/UnusedMethodArgument
          settings = DEFAULT_METRIC_SETTINGS.merge(metric_settings)
          validate_metric_settings(settings)

          MetricStore.new(metric_name:     metric_name,
                          connection_pool: @connection_pool,
                          metric_settings: settings)
        end

        private

        def validate_metric_settings(metric_settings)
          raise(InvalidStoreSettingsError, "Metrics need a valid :aggregation key") unless metric_settings.key?(:aggregation) && AGGREGATION_MODES.include?(metric_settings[:aggregation])
          raise(InvalidStoreSettingsError, "Only :aggregation setting can be specified") unless (metric_settings.keys - %i[aggregation]).empty?
        end

        class MetricStore
          attr_reader(:metric_name, :connection_pool)

          def initialize(metric_name:, connection_pool:, metric_settings:)
            @metric_name = metric_name
            @connection_pool = connection_pool
            @values_aggregation_mode = metric_settings[:aggregation]
          end

          def synchronize(&)
            connection_pool.with do |conn|
              conn.pipelined(&) # this will checkout a connection again. That's fine, it'll be the same connection
            end
          end

          def set(labels:, val:)
            connection_pool.with do |conn|
              field = hash_key(labels)
              if @values_aggregation_mode == MOST_RECENT
                conn.pipelined do
                  conn.hset(redis_key, field, val)
                  conn.hset(redis_timestamps_key, field, current_timestamp.to_f)
                end
              else
                conn.hset(redis_key, field, val)
              end
            end
          end

          def increment(labels:, by: 1)
            connection_pool.with do |conn|
              field = hash_key(labels)
              if @values_aggregation_mode == MOST_RECENT
                conn.pipelined do
                  conn.hincrbyfloat(redis_key, field, by)
                  conn.hset(redis_timestamps_key, field, current_timestamp.to_f)
                end
              else
                conn.hincrbyfloat(redis_key, field, by)
              end
            end
          end

          def get(labels:)
            connection_pool.with do |conn|
              conn.hget(redis_key, hash_key(labels)).to_f
            end
          end

          def all_values
            raw_redis, raw_timestamps = connection_pool.with do |conn|
              if @values_aggregation_mode == MOST_RECENT
                [conn.hgetall(redis_key), conn.hgetall(redis_timestamps_key)]
              else
                [conn.hgetall(redis_key), {}]
              end
            end
            raw_redis ||= {}
            raw_timestamps ||= {}

            labelset_data = raw_redis.each_with_object({}) do |(labels_qs, v), acc|
              # Labels come as a query string. CGI.parse was removed in Ruby 4.0, so decode with
              # URI.decode_www_form instead and turn the keys back into symbols.
              # "foo=bar&x=y" => { foo: "bar", x: "y" }
              labels = URI.decode_www_form(labels_qs).each_with_object({}) do |(k, v), acc|
                acc[k.to_sym] ||= v
              end

              label_set = labels.except(:__pid)
              acc[label_set] ||= []
              if @values_aggregation_mode == MOST_RECENT
                acc[label_set] << {
                  value:      v.to_f, # Value comes back from redis as String
                  updated_at: raw_timestamps.fetch(labels_qs, "0").to_f,
                }
              else
                acc[label_set] << v.to_f # Value comes back from redis as String
              end
            end

            # Aggregate all the different values for each label_set
            labelset_data.transform_values do |values|
              aggregate_values(values)
            end
          end

          private

          def redis_key
            @redis_key ||= "metric_#{metric_name}"
          end

          def redis_timestamps_key
            @redis_timestamps_key ||= "metric_#{metric_name}_timestamps"
          end

          def hash_key(labels)
            key = labels.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
            key << "&__pid=" << process_id.to_s
          end

          def process_id
            Process.pid
          end

          def current_timestamp
            Process.clock_gettime(Process::CLOCK_REALTIME)
          end

          def aggregate_values(values)
            case @values_aggregation_mode
            when SUM
              values.inject { |sum, element| sum + element }
            when MAX
              values.max
            when MIN
              values.min
            when MOST_RECENT
              values.max_by { |entry| entry[:updated_at] }[:value]
            else
              raise(InvalidStoreSettingsError, "Invalid Aggregation Mode: #{@values_aggregation_mode}")
            end
          end
        end

        private_constant(:MetricStore)
      end
    end
  end
end
