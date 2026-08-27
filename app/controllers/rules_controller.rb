# frozen_string_literal: true

class RulesController < ApplicationController
  before_action(:load_categories, only: %i[index new create edit update order])
  respond_to(:html, :json)
  respond_to(:js, only: %i[reorder])

  def index
    @wiki = view_context.safe_wiki(AdminConfig.instance.rules_body_wiki_page)
    respond_to do |format|
      format.html
      format.json { render(json: { rules: Rule.order(:category_id, :order), categories: @categories, body: @wiki }) }
    end
  end

  def new
    @rule = authorize(Rule.new_with_current(:creator, permitted_attributes(Rule)))
  end

  def edit
    @rule = authorize(Rule.find(params[:id]))
  end

  def create
    @rule = authorize(Rule.new_with_current(:creator, permitted_attributes(Rule)))
    @rule.save
    notice(@rule.errors.any? ? @rule.errors.full_messages.join(";") : "Rule created")
    respond_with(@rule, location: rules_path)
  end

  def update
    @rule = authorize(Rule.find(params[:id]))
    @rule.update_with_current(:updater, permitted_attributes(@rule))
    notice(@rule.errors.any? ? @rule.errors.full_messages.join(";") : "Rule updated")
    respond_with(@rule, location: rules_path)
  end

  def destroy
    @rule = authorize(Rule.find(params[:id]))
    @rule.destroy_with_current(:destroyer)
    notice("Rule deleted")
    respond_with(@rule, location: rules_path)
  end

  def order
    authorize(Rule).html_includes(request, :creator)
  end

  def reorder
    authorize(Rule)
    return render_expected_error(400, "No rules provided") unless params[:_json].is_a?(Array) && params[:_json].any?
    changes = 0
    Rule.transaction do
      params[:_json].each do |data|
        rule = Rule.find(data[:id])
        rule.update(order: data[:order])
        rule.update(category_id: data[:category_id]) if data[:category_id].present?
        changes += 1 if rule.previous_changes.any?
      end

      rules = Rule.all
      if rules.any? { |rule| !rule.valid? }
        errors = []
        rules.each do |rule|
          errors << { id: rule.id, name: rule.name, message: rule.errors.full_messages.join("; ") } if !rule.valid? && rule.errors.any?
        end
        render(json: { success: false, errors: errors }, status: :unprocessable_entity)
        raise(ActiveRecord::Rollback)
      else
        Rule.log_reorder(changes, CurrentUser.user) if changes != 0
        respond_to do |format|
          format.json { head(:no_content) }
          format.js do
            render(json: { html: render_to_string(partial: "rules/sort", locals: { categories: RuleCategory.order(:order) }) })
          end
        end
      end
    end
  rescue ActiveRecord::InvalidForeignKey
    render_expected_error(400, "Invalid category")
  rescue ActiveRecord::RecordNotFound
    render_expected_error(400, "Rule not found")
  end

  def builder
    authorize(Rule)
    render(json: {
      section:   render_to_string(partial: "record_builder/body", locals: { id: "{id}" }, formats: %i[html]),
      quick_mod: QuickRule.order(:order).map { |q| q.slice(:reason, :header).merge(rule: q.rule.anchor) },
      rules:     Rule.all.to_h { |r| [r.anchor, r.slice(:name, :description)] },
    }.to_json)
  end

  private

  def load_categories
    @categories = RuleCategory.html_includes(request, :creator, rules: :creator).order(:order)
  end
end
