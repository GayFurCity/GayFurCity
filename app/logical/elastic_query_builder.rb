# frozen_string_literal: true

class ElasticQueryBuilder
  attr_accessor(:q, :must, :must_not, :should, :order, :user)

  def initialize(query, user)
    @q = query
    @must = [] # These terms are ANDed together
    @must_not = [] # These terms are NOT ANDed together
    @should = [] # These terms are ORed together
    @order = []
    @function_score = nil
    @user = user
    build
  end

  def search
    model_class.document_store.search(search_body, request_timeout: elasticsearch_request_timeout)
  end

  def search_body
    if must.empty?
      must.push({ match_all: {} })
    end

    query = {
      bool: {
        must:     must,
        must_not: must_not,
        should:   should,
      },
    }

    query[:bool][:minimum_should_match] = 1 if should.any?

    if @function_score.present?
      @function_score[:query] = query
      query = { function_score: @function_score }
    end

    body = {
      query:   query,
      sort:    order,
      _source: false,
    }
    # Omitted (rather than sent as a literal "Infinityms") when an admin configures -1/unlimited -
    # ES treats a missing timeout as "run to completion", the same intent.
    body[:timeout] = "#{elasticsearch_query_timeout.to_i}ms" if elasticsearch_query_timeout.finite?
    body
  end

  def elasticsearch_query_timeout
    timeout = user ? Config.get_user(:elasticsearch_query_timeout, user) : 3_000
    timeout.is_a?(Numeric) ? timeout : 3_000
  end

  # In seconds, not ms - matches what Elasticsearch::Client#request_timeout natively expects.
  def elasticsearch_request_timeout
    timeout = user ? Config.get_user(:elasticsearch_request_timeout, user) : 5
    timeout.is_a?(Numeric) ? timeout : 5
  end

  def match_any(*args)
    # Explicitly set minimum should match, even though it may not be required in this context.
    { bool: { minimum_should_match: 1, should: args } }
  end

  def match_none(*args)
    { bool: { must_not: args } }
  end

  def range_relation(arr, field)
    return if arr.nil?
    return if arr.size < 2
    return if arr[1].nil?

    case arr[0]
    when :eq
      if arr[1].is_a?(Time)
        { range: { field => { gte: arr[1].beginning_of_day, lte: arr[1].end_of_day } } }
      else
        { term: { field => arr[1] } }
      end
    when :gt
      { range: { field => { gt: arr[1] } } }
    when :gte
      { range: { field => { gte: arr[1] } } }
    when :lt
      { range: { field => { lt: arr[1] } } }
    when :lte
      { range: { field => { lte: arr[1] } } }
    when :in
      { terms: { field => arr[1] } }
    when :between
      { range: { field => { gte: arr[1], lte: arr[2] } } }
    end
  end

  def add_array_range_relation(key, index_field)
    if q[key]
      must.concat(q[key].map { |x| range_relation(x, index_field) })
    end

    if q[:"#{key}_must_not"]
      must_not.concat(q[:"#{key}_must_not"].map { |x| range_relation(x, index_field) })
    end

    if q[:"#{key}_should"]
      should.concat(q[:"#{key}_should"].map { |x| range_relation(x, index_field) })
    end
  end

  def add_array_relation(key, index_field, any_none_key: nil, action: :term, cast: :itself)
    if q[key]
      must.concat(q[key].map(&cast).map { |x| { action => { index_field => x } } })
    end

    if q[:"#{key}_must_not"]
      must_not.concat(q[:"#{key}_must_not"].map(&cast).map { |x| { action => { index_field => x } } })
    end

    if q[:"#{key}_should"]
      should.concat(q[:"#{key}_should"].map(&cast).map { |x| { action => { index_field => x } } })
    end

    if q[any_none_key] == "any"
      must.push({ exists: { field: index_field } })
    elsif q[any_none_key] == "none"
      must_not.push({ exists: { field: index_field } })
    end

    if q[:"#{any_none_key}_should"] == "any"
      should.push({ exists: { field: index_field } })
    elsif q[:"#{any_none_key}_should"] == "none"
      should.push(match_none({ exists: { field: index_field } }))
    end
  end

  def add_boolean_exists_relation(key, index_field)
    if q.include?(key)
      (q[key] ? must : must_not).push({ exists: { field: index_field } })
    end

    if q.include?(:"#{key}_must_not")
      (q[:"#{key}_must_not"] ? must_not : must).push({ exists: { field: index_field } })
    end

    if q.include?(:"#{key}_should")
      should.push({ bool: { must: [{ exists: { field: index_field } }] } })
    end
  end

  def add_boolean_relation(key, index_field)
    if q.include?(key)
      must.push({ term: { index_field => q[key] } })
    end

    if q.include?(:"#{key}_must_not")
      must_not.push({ term: { index_field => q[:"#{key}_must_not"] } })
    end

    if q.include?(:"#{key}_should")
      should.push({ term: { index_field => q[:"#{key}_should"] } })
    end
  end

  def add_boolean_match(key, index_field)
    return if q[key].blank?
    if q[key].to_s.truthy?
      must.push({ term: { index_field => true } })
    elsif q[key].to_s.falsy?
      must.push({ term: { index_field => false } })
    else
      raise(ArgumentError, "value must be truthy or falsy")
    end
  end

  def add_range_relation(key, index_field, type: :integer)
    if q[key].present?
      must.push(range_relation(ParseValue.range(q[key], type), index_field))
    end
  end

  def add_text_match(key, index_field)
    value = q[key]
    return if value.blank?
    must.push(match: { index_field => value })
  end

  def apply_basic_order(key: :order)
    case q[key]
    when "id_asc"
      order.push({ id: { order: "asc" } })
    when "id_desc"
      order.push({ id: { order: "desc" } })
    else
      apply_default_order
    end
  end

  def apply_default_order
    order.push({ id: { order: "desc" } })
  end
end
