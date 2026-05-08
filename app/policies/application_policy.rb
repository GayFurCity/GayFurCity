# frozen_string_literal: true

class ApplicationPolicy
  attr_reader(:user, :record)

  def initialize(user, record)
    @user = user || User.anonymous
    @record = record
  end

  def index?
    true
  end

  def show?
    index?
  end

  def search?
    index?
  end

  def new?
    create?
  end

  def create?
    member?
  end

  def edit?
    update?
  end

  def update?
    member?
  end

  def delete?
    destroy?
  end

  def destroy?
    member?
  end

  def unbanned?
    logged_in? && !user.is_banned?
  end

  def member?
    user.is_member?
  end

  def logged_in?
    !user.is_anonymous?
  end

  def approver?
    user.is_approver?
  end

  def can_search_ip_addr?
    user.is_admin?
  end

  def can_see_ip_addr?
    user.is_admin?
  end

  def can_see_email?
    user.is_admin?
  end

  def lockdown?(type)
    !(user.is_staff? || !Security::Lockdown.public_send("#{type}_disabled?"))
  end

  def all?(*methods)
    methods.all? { |name| respond_to?(name) ? send(name) : false }
  end

  def any?(*methods)
    methods.any? { |name| respond_to?(name) ? send(name) : false }
  end

  def policy(object)
    Pundit.policy!(user, object)
  end

  def permitted_attributes
    []
  end

  def permitted_attributes_for_create
    permitted_attributes
  end

  def permitted_attributes_for_update
    permitted_attributes
  end

  def permitted_attributes_for_new
    permitted_attributes_for_create
  end

  def permitted_attributes_for_edit
    permitted_attributes_for_update
  end

  def can_use_attribute?(attrs, action = nil)
    attrs = [attrs] unless attrs.is_a?(Array)
    permitted = action.nil? || !respond_to?("permitted_attributes_for_#{action}") ? permitted_attributes : send("permitted_attributes_for_#{action}")
    hash_permitted = permitted.grep(Hash).flat_map(&:keys)
    attrs.all? { |attr| permitted.include?(attr) || hash_permitted.include?(attr) }
  end

  alias can_use_attributes? can_use_attribute?

  def can_use_any_attribute?(*attrs, action: nil)
    attrs.any? { |attr| can_use_attribute?(attr, action) }
  end

  def can_search_attribute?(attr)
    permitted = permitted_search_params
    Array(attr).all? { |a| permitted.include?(a) }
  end

  alias can_search_attributes? can_search_attribute?

  def visible_for_search(relation)
    relation
  end

  def permitted_search_params
    %i[id created_at updated_at order]
  end

  def nested_search_params(**kwargs)
    [kwargs.transform_values { |v| policy(v).permitted_search_params }]
  end

  def api_attributes
    attr = record.class.column_names.map(&:to_sym)
    attr -= attr.select { |a| a.to_s.include?("ip_addr") } unless can_see_ip_addr?
    attr
  end

  def html_data_attributes
    data_attributes = record.class.columns.select do |column|
      column.type.in?(%i[integer boolean datetime float uuid interval]) && !column.array?
    end.map(&:name).map(&:to_sym)

    api_attributes & data_attributes
  end
end
