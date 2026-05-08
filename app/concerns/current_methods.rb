# frozen_string_literal: true

module CurrentMethods
  extend(ActiveSupport::Concern)

  module ClassMethods
    def search_current(params, ...)
      search(params, CurrentUser.user, ...)
    end

    def with_current(instance, method, *args, **, &)
      attr = args.grep(Symbol)
      other = args - attr
      hashes = other.grep(Hash)
      params = other.grep(ActionController::Parameters)
      other -= hashes + params
      other.compact_blank!
      options = [attr.index_with(CurrentUser.user), *hashes, *params.map(&:to_hash)].inject(:merge)
      instance.send(method, *other, **options, **, &)
    end

    def new_with_current(...)
      with_current(self, :new, ...)
    end

    def create_with_current(...)
      with_current(self, :create, ...)
    end

    def create_with_current!(...)
      with_current(self, :create!, ...)
    end
  end

  def update_with_current(...)
    self.class.with_current(self, :update, ...)
  end

  def update_with_current!(...)
    self.class.with_current(self, :update!, ...)
  end

  def destroy_with_current(*attrs)
    attrs.each do |attr|
      send("#{attr}=", CurrentUser.user)
    end
    destroy
  end

  def destroy_with_current!(*attrs)
    attrs.each do |attr|
      send("#{attr}=", CurrentUser.user)
    end
    destroy!
  end
end
