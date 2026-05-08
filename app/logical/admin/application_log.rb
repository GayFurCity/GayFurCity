# frozen_string_literal: true

module Admin
  class ApplicationLog
    Entry = Struct.new(:id, :line_number, :text, keyword_init: true)

    attr_reader(:environment, :path)

    def initialize(environment: Rails.env, path: self.class.path_for(environment))
      @environment = environment
      @path = path.to_s
    end

    def entries(page: 1, limit: 100)
      current_page = normalize_page(page)
      records_per_page = normalize_limit(limit)
      total_count = line_count
      total_pages = [(total_count.to_f / records_per_page).ceil, 1].max
      current_page = [current_page, total_pages].min

      start_index = [total_count - (current_page * records_per_page), 0].max
      end_index = total_count - ((current_page - 1) * records_per_page) - 1

      records = if exists? && total_count > 0 && start_index <= end_index
                  lines_between(start_index, end_index).reverse
                else
                  []
                end

      GayFurCity::Paginator::PaginatedArray.new(records, pagination_mode: :numbered, records_per_page: records_per_page, total_count: total_count, current_page: current_page)
    end

    def exists?
      File.exist?(path)
    end

    def filename
      File.basename(path)
    end

    def total_count
      @total_count ||= exists? ? File.foreach(path).count : 0
    end

    def self.path_for(environment = Rails.env)
      Rails.root.join("log", "#{environment}.log")
    end

    private

    def normalize_page(page)
      [page.to_i, 1].max
    end

    def normalize_limit(limit)
      limit = limit.present? ? limit.to_i : 100
      limit.clamp(1, Config.instance.max_per_page)
    end

    def line_count
      total_count
    end

    def lines_between(start_index, end_index)
      rows = []

      File.foreach(path).with_index do |line, index|
        next if index < start_index
        break if index > end_index

        rows << Entry.new(id: index + 1, line_number: index + 1, text: line.chomp)
      end

      rows
    end
  end
end
