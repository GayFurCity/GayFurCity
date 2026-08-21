# frozen_string_literal: true

module GayFurCity
  module Paginator
    module ActiveRecordExtension
      include(BaseExtension)

      def paginate_numbered
        # Without an explicit order, LIMIT/OFFSET has no guaranteed row order - it usually matches
        # insertion order in practice, but isn't guaranteed, and can flip under a different query
        # plan. Only default it, mirroring DocumentStoreExtensions#paginate_numbered - a caller that
        # already applied its own order (e.g. a search with an explicit order:) is left alone.
        q = order_values.empty? ? order(id: :asc) : self
        q.limit(records_per_page).offset((current_page - 1) * records_per_page)
      end

      def paginate_sequential_before
        q = limit(records_per_page + 1)
        q = q.where("#{table_name}.id < ?", current_page)
        q.reorder("#{table_name}.id desc")
      end

      def paginate_sequential_after
        q = limit(records_per_page + 1)
        q = q.where("#{table_name}.id > ?", current_page)
        q.reorder("#{table_name}.id asc")
      end

      def is_first_page?
        case @pagination_mode
        when :numbered
          current_page == 1
        when :sequential_before
          false
        when :sequential_after
          paginator_raw_records.size <= records_per_page
        end
      end

      def is_last_page?
        case @pagination_mode
        when :numbered
          current_page >= total_pages
        when :sequential_before
          paginator_raw_records.size <= records_per_page
        when :sequential_after
          false
        end
      end

      # In sequential pagination we fetch one more record than we need
      # so that we can tell when we're on the first or last page. Here we override
      # a rails internal method to discard that extra record. See #2044, #3642.
      #
      # is_first_page?/is_last_page? need that extra row to tell whether the lookahead actually came
      # back, but records/to_a/etc. below always show the truncated (records_per_page) result - stash
      # the untruncated fetch in @paginator_raw_records so they still have something to check against.
      def records
        case @pagination_mode
        when :numbered
          super
        when :sequential_before
          @paginator_raw_records = super
          @paginator_raw_records.first(records_per_page)
        when :sequential_after
          @paginator_raw_records = super
          @paginator_raw_records.first(records_per_page).reverse
        end
      end

      def paginator_raw_records
        records
        @paginator_raw_records
      end

      # taken from kaminari (https://github.com/amatsuda/kaminari)
      def real_count
        c = except(:offset, :limit, :order)
        c = c.reorder(nil)
        c = c.count
        c.respond_to?(:count) ? c.count : c
      rescue ActiveRecord::StatementInvalid => e
        if e.to_s =~ /statement timeout/
          1_000_000
        else
          raise
        end
      end
    end
  end
end
