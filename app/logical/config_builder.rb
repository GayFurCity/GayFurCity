# frozen_string_literal: true

require_relative("../../config/initializers/02_core_extensions")

class ConfigBuilder
  include(Singleton)

  cattr_accessor(:list, default: [])
  cattr_accessor(:env_set, default: {})
  cattr_accessor(:unset, default: [])
  cattr_accessor(:required, default: [])
  cattr_accessor(:reviver_map, default: {})
  cattr_accessor(:subconfigs, default: Hash.new { |h, k| h[k] = {} })

  def self.config(name, type = :string, env: true, required: false, blank: false, &block)
    name = name.to_sym
    remove_config(name) if list.include?(name)
    list << name
    self.required << name if required
    if block.nil?
      unset << name
      block = -> { raise(NotImplementedError, "Config option #{name} is not set") }
    end
    define_method(name) do |*args|
      env_or_value(name, args, blank: blank, &block)
    end
    if type == :boolean
      define_method("#{name}?") do |*args|
        public_send(name, *args)
      end
    end
    if type && type != :string
      reviver(name, type)
    end
    env_set[name] = env
  end

  def self.remove_config(name, reviver: false)
    name = name.to_sym
    list.delete(name)
    required.delete(name)
    unset.delete(name)
    reviver_map.delete(name) if reviver
    env_set.delete(name)
    remove_method(name)
    remove_method("#{name}?") if method_defined?("#{name}?")
  end

  def env_or_value(name, args, blank: false, &)
    value = env(name)
    value = nil if !value.nil? && value.blank? && !blank
    if value.nil?
      instance_exec(*args, &)
    else
      reviver = reviver_map.fetch(name, proc(&:itself))
      instance_exec(value, *args, &reviver)
    end
  end

  def env(name)
    ENV.fetch("GAYFURCITY_#{name.to_s.upcase}", nil)
  end

  def self.reviver(name, type = nil, &block)
    if block
      reviver_map[name] = block
      return
    end
    method = case type
             when :boolean
               ->(v) { v.to_b }
             when :integer
               ->(v) { v.to_i }
             when :symbol
               ->(v) { v.to_sym }
             when :array
               ->(v) { v.split(/\s*,\s*/) }
             else
               raise(ArgumentError, "not sure how to revive #{type} for #{method}")
             end
    reviver_map[name] = method
  end

  def self.subconfig(prefix, parent: [], &block)
    raise(ArgumentError, "block required") unless block

    prefix = prefix.to_sym
    path   = parent + [prefix]

    node = subconfigs
    path.each do |p|
      node[p] ||= {}
      node = node[p]
    end

    unless method_defined?(prefix)
      define_method(prefix) { SubconfigProxy.new(self, path) }
    end

    collector = Module.new do
      def self.collected
        @collected ||= []
      end

      def self.config(name, type = :string, env: true, required: false, blank: false, &block)
        collected << [:config, name, type, env, required, blank, block]
      end

      def self.reviver(name, type = nil, &block)
        collected << [:reviver, name, type, block]
      end

      def self.subconfig(name, &block)
        collected << [:subconfig, name, block]
      end
    end

    collector.module_eval(&block)

    collector.collected.each do |kind, name, *args|
      case kind
      when :config
        full = (path + [name]).join("_").to_sym
        config(full, args[0], env: args[1], required: args[2], blank: args[3], &args[4])
      when :reviver
        full = (path + [name]).join("_").to_sym
        reviver(full, args[0], &args[1])
      when :subconfig
        subconfig(name, parent: path, &args[0])
      end
    end
  end

  def self.ensure_required_set!
    unset = []
    required.each do |name|
      value = begin
        instance.public_send(name)
      rescue StandardError
        nil
      end
      unset << name if value.blank?
    end

    raise("Missing required configuration options: #{unset.join(', ')}") if unset.any?
  end

  def present?(*names)
    names.flatten.all? { |name| public_send(name).present? }
  end

  class SubconfigProxy
    def initialize(owner, path)
      @owner = owner
      @path  = path
    end

    def method_missing(name, *, &)
      name = name.to_sym
      full_path = @path + [name]

      flat = full_path.join("_").to_sym
      if @owner.respond_to?(flat)
        return @owner.public_send(flat, *, &)
      end

      if subconfig_path?(full_path)
        return SubconfigProxy.new(@owner, full_path)
      end

      super
    end

    def respond_to_missing?(name, include_private = false)
      name = name.to_sym
      flat = (@path + [name]).join("_").to_sym

      @owner.respond_to?(flat, include_private) ||
        subconfig_path?(@path + [name]) ||
        super
    end

    def self.include_local
      instance_exec
    end

    private

    def subconfig_path?(path)
      node = ConfigBuilder.subconfigs
      path.each do |p|
        return false unless node.key?(p)
        node = node[p]
      end
      true
    end
  end
end
