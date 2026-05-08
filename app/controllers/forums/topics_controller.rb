# frozen_string_literal: true

module Forums
  class TopicsController < ApplicationController
    respond_to(:html, :json)
    before_action(:load_topic, except: %i[index new create])
    before_action(:ensure_lockdown_disabled, except: %i[index show])
    skip_before_action(:api_check)

    def index
      params[:search] ||= {}
      params[:search][:order] ||= "sticky" if request.format.html?

      @query = authorize(ForumTopic).html_includes(request, :creator, :updater, :category, :statuses, posts: :creator, last_post: :creator)
                                    .search_current(search_params(ForumTopic))
      @forum_topics = @query.paginate(params[:page], limit: params[:limit] || 50)

      respond_with(@forum_topics) do |format|
        format.html do
          # TODO: revisit muting, it may need to be further optimized or removed due to performance issues

          @category = ForumCategory.find_by(id: params.dig(:search, :category_id)) if params.dig(:search, :category_id).present?
        end
      end
    end

    def show
      authorize(@forum_topic)
      if request.format.html?
        @forum_topic.mark_as_read!(CurrentUser.user)
      end
      @forum_posts = ForumPost.html_includes(request, :creator, :spam_ticket, :last_edit_version, topic: %i[category original_post], votes: %i[user])
                              .permitted(CurrentUser.user)
                              .search_current({ topic_id: @forum_topic.id, visible: false })
                              .reorder("forum_posts.id")
                              .paginate(params[:page])
      respond_with(@forum_topic)
    end

    def new
      @forum_topic = authorize(ForumTopic.new_with_current(:creator, permitted_attributes(ForumTopic)))
      @forum_topic.original_post = ForumPost.new_with_current(:creator, permitted_attributes(ForumTopic)[:original_post_attributes])
      respond_with(@forum_topic)
    end

    def edit
      authorize(@forum_topic)
      respond_with(@forum_topic)
    end

    def create
      @forum_topic = authorize(ForumTopic.new_with_current(:creator, permitted_attributes(ForumTopic)))
      @forum_topic.save
      respond_with(@forum_topic)
    end

    def update
      authorize(@forum_topic)
      @forum_topic.update_with_current(:updater, permitted_attributes(@forum_topic))
      respond_with(@forum_topic)
    end

    def destroy
      authorize(@forum_topic)
      @forum_topic.destroy_with_current(:destroyer)
      notice("Topic deleted")
      respond_with(@forum_topic, location: forum_topics_path)
    end

    def hide
      authorize(@forum_topic)
      @forum_topic.hide!(CurrentUser.user)
      if @forum_topic.errors.any?
        respond_with(@forum_topic) do |format|
          format.html do
            redirect_back_or_to(forum_topic_path(@forum_topic), notice: "Failed to hide topic: #{@forum_topic.errors.full_messages.join('; ')}")
          end
        end
      else
        notice("Topic hidden")
        respond_with(@forum_topic)
      end
    end

    def unhide
      authorize(@forum_topic)
      @forum_topic.unhide!(CurrentUser.user)
      notice("Topic unhidden")
      respond_with(@forum_topic)
    end

    def lock
      authorize(@forum_topic)
      @forum_topic.update_with_current(:updater, is_locked: true)
      notice("Topic locked")
      respond_with(@forum_topic)
    end

    def unlock
      authorize(@forum_topic)
      @forum_topic.update_with_current(:updater, is_locked: false)
      notice("Topic unlocked")
      respond_with(@forum_topic)
    end

    def sticky
      authorize(@forum_topic)
      @forum_topic.update_with_current(:updater, is_sticky: true)
      notice("Topic stickied")
      respond_with(@forum_topic)
    end

    def unsticky
      authorize(@forum_topic)
      @forum_topic.update_with_current(:updater, is_sticky: false)
      notice("Topic unstickied")
      respond_with(@forum_topic)
    end

    def mark_as_read
      authorize(@forum_topic)
      @forum_topic.mark_as_read!(CurrentUser.user)
      respond_to do |format|
        format.html { redirect_back_or_to(forum_topic_path(@forum_topic)) }
        format.json
      end
    end

    def subscribe
      authorize(@forum_topic)
      status = ForumTopicStatus.find_by(forum_topic_id: @forum_topic, user_id: CurrentUser.user.id)
      if status
        status.update(subscription: true, subscription_last_read_at: @forum_topic.updated_at, mute: false)
      else
        ForumTopicStatus.create(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id, subscription_last_read_at: @forum_topic.updated_at, subscription: true)
      end
      respond_with(@forum_topic)
    end

    def unsubscribe
      authorize(@forum_topic)
      status = ForumTopicStatus.find_by(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id, subscription: true)
      status&.destroy
      respond_with(@forum_topic)
    end

    def mute
      authorize(@forum_topic)
      status = ForumTopicStatus.find_by(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id)
      if status
        status.update(mute: true, subscription: false, subscription_last_read_at: nil)
      else
        ForumTopicStatus.create(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id, mute: true)
      end
      respond_with(@forum_topic)
    end

    def unmute
      authorize(@forum_topic)
      status = ForumTopicStatus.find_by(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id, mute: true)
      status&.destroy
      respond_with(@forum_topic)
    end

    private

    def load_topic
      @forum_topic = ForumTopic.includes(:category).find(params[:id])
    end

    def ensure_lockdown_disabled
      access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.user.is_staff?
    end
  end
end
