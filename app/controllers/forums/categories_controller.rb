# frozen_string_literal: true

module Forums
  class CategoriesController < ApplicationController
    before_action(:load_forum_category, only: %i[show edit update destroy move_all_topics mark_as_read])
    respond_to(:html, :json)

    def index
      @forum_categories = authorize(ForumCategory).visible(CurrentUser.user)
                                                  .ordered_categories
                                                  .paginate(params[:page], limit: params[:limit] || 50)
      respond_with(@forum_categories)
    end

    def show
      authorize(@forum_category)
      respond_with(@forum_category) do |format|
        format.html { redirect_to(forum_topics_path(search: { category_id: @forum_category.id })) }
      end
    end

    def new
      @forum_category = authorize(ForumCategory.new_with_current(:creator, permitted_attributes(ForumCategory)))
    end

    def edit
      authorize(@forum_category)
    end

    def create
      @forum_category = authorize(ForumCategory.new_with_current(:creator, permitted_attributes(ForumCategory)))
      @forum_category.save
      notice(@forum_category.valid? ? "Forum category created" : @forum_category.errors.full_messages.join("; "))
      respond_with(@forum_category) do |format|
        format.html { redirect_to(forum_categories_path) }
      end
    end

    def update
      authorize(@forum_category).update_with_current(:updater, permitted_attributes(ForumCategory))

      notice(@forum_category.valid? ? "Category updated" : @forum_category.errors.full_messages.join("; "))
      respond_with(@forum_category, location: forum_categories_path)
    end

    def destroy
      authorize(@forum_category).destroy_with_current(:destroyer)
      notice(@forum_category.errors.any? ? @forum_category.errors.full_messages.join("; ") : "Forum category deleted")
      respond_with(@forum_category, location: forum_categories_path)
    end

    def reorder
      authorize(ForumCategory)
      new_orders = params[:_json].reject { |o| o[:id].nil? }
      new_ids = new_orders.pluck(:id)
      current_ids = ForumCategory.pluck(:id)
      missing = current_ids - new_ids
      extra = new_ids - current_ids
      duplicate = new_ids.select { |id| new_ids.count(id) > 1 }.uniq

      return render_expected_error(400, "Missing ids: #{missing.join(', ')}") if missing.any?
      return render_expected_error(400, "Extra ids provided: #{extra.join(', ')}") if extra.any?
      return render_expected_error(400, "Duplicate ids provided: #{duplicate.join(', ')}") if duplicate.any?

      changes = 0
      ForumCategory.transaction do
        new_orders.each do |order|
          rec = ForumCategory.find(order[:id])
          if rec.order != order[:order]
            rec.update_column(:order, order[:order])
            changes += 1
          end
        end
      end

      ForumCategory.log_reorder(changes, CurrentUser.user) if changes != 0

      respond_to do |format|
        format.html do
          notice("Order updated")
          redirect_back_or_to(forum_categories_path)
        end
        format.json
      end
    rescue ActiveRecord::RecordNotFound
      render_expected_error(400, "Category not found")
    end

    def move_all_topics
      authorize(ForumCategory)
      unless @forum_category.can_move_topics?
        return render_expected_error(400, "Forum category cannot have more than #{ForumCategory::MAX_TOPIC_MOVE_COUNT} topics")
      end
      if request.get?
        return respond_with(@forum_category)
      end
      @new_forum_category = ForumCategory.find(permitted_attributes(ForumCategory)[:new_category_id])
      @forum_category.move_all_topics(@new_forum_category, CurrentUser.user)
      respond_to do |format|
        format.html { redirect_to(forum_categories_path, notice: "The category is now locked, topics will be moved soon") }
        format.json { head(204) }
      end
    end

    def mark_as_read
      authorize(ForumCategory)
      @forum_category.mark_as_read!(CurrentUser.user)
      respond_to do |format|
        format.html { redirect_back_or_to(forum_category_path(@forum_category)) }
        format.json { head(204) }
      end
    end

    def mark_all_as_read
      authorize(ForumCategory)
      ForumCategory.mark_all_as_read!(CurrentUser.user)
      respond_to do |format|
        format.html { redirect_back_or_to(forums_path) }
        format.json { head(204) }
      end
    end

    private

    def load_forum_category
      @forum_category = ForumCategory.find(params[:id])
    end
  end
end
