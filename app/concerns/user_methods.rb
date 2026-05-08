# frozen_string_literal: true

module UserMethods
  extend(ActiveSupport::Concern)

  module ClassMethods
    def belongs_to_user(*, **)
      UserAttribute.new(self, *, **, db: true)
    end

    def resolvable(*, **)
      UserAttribute.new(self, *, **, db: false)
    end

    def with_user(instance, method, user, *args, **, &)
      default = { new: :creator, create: :creator, create!: :creator, update: :updater, update!: :updater, destroy: :destroyer, destroy!: :destroyer }.fetch(method)
      attrs = args.grep(Symbol)
      attrs = [default] if default && attrs.empty?
      other = args - attrs
      hashes = other.grep(Hash)
      params = other.grep(ActionController::Parameters)
      other -= hashes + params
      other.compact_blank!
      options = [attrs.index_with(user), *hashes, *params.map(&:to_hash)].inject(:merge)
      if %i[destroy destroy!].include?(method)
        options.each do |attr, value|
          instance.send("#{attr}=", value)
        end
        instance.send(method)
      else
        instance.send(method, *other, **options, **, &)
      end
    end

    def new_with(...)
      with_user(self, :new, ...)
    end

    def create_with(...)
      new_with(...).tap(&:save)
    end

    def create_with!(...)
      new_with(...).tap(&:save!)
    end
  end

  def update_with(...)
    self.class.with_user(self, :update, ...)
  end

  def update_with!(...)
    self.class.with_user(self, :update!, ...)
  end

  def destroy_with(...)
    self.class.with_user(self, :destroy, ...)
  end

  def destroy_with!(...)
    self.class.with_user(self, :destroy!, ...)
  end

  private

  def put(attr, value, overwrite: false)
    if respond_to?(:"#{attr}_id")
      send(:"#{attr}=", value) if overwrite || send(:"#{attr}_id").blank?
    elsif respond_to?(attr)
      send(:"#{attr}=", value) if overwrite || send(attr).blank?
    end
  end
end
