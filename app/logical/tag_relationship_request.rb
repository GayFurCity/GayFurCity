# frozen_string_literal: true

class TagRelationshipRequest
  include(ActiveModel::Validations)

  attr_reader(:antecedent_name, :consequent_name, :user, :tag_relationship, :reason, :forum_topic, :forum_topic_id, :skip_forum)

  validates(:reason, length: { minimum: 5 }, unless: :skip_forum)
  validate(:validate_tag_relationship)
  validate(:validate_forum_topic)

  def initialize(antecedent_name:, consequent_name:, user:, reason: nil, skip_forum: false, forum_topic: nil, forum_topic_id: nil)
    @antecedent_name = antecedent_name&.strip&.tr(" ", "_")
    @consequent_name = consequent_name&.strip&.tr(" ", "_")
    @user = user
    @reason = reason
    @skip_forum = skip_forum.to_s.truthy?
    if forum_topic.present?
      @forum_topic = forum_topic
      @forum_topic_id = forum_topic.id
    elsif forum_topic_id.present?
      @forum_topic = ForumTopic.find_by(id: forum_topic_id)
      @forum_topic_id = forum_topic_id
    end
  end

  def self.create(...)
    new(...).create
  end

  def create
    return self if invalid?

    tag_relationship_class.transaction do
      @tag_relationship = build_tag_relationship
      @tag_relationship.save

      unless skip_forum
        if forum_topic.present?
          forum_post = @forum_topic.posts.create(tag_change_request: @tag_relationship, body: "Reason: #{reason}", allow_voting: true, creator: user)
        else
          @forum_topic = build_forum_topic
          @forum_topic.save
          forum_post = @forum_topic.posts.first
          forum_post.update(tag_change_request: @tag_relationship, allow_voting: true, updater: user)
        end

        @tag_relationship.forum_topic_id = @forum_topic.id
        @tag_relationship.forum_post_id = forum_post.id
        @tag_relationship.save
      end
    end

    self
  end

  def build_tag_relationship
    tag_relationship_class.new(
      antecedent_name: antecedent_name,
      consequent_name: consequent_name,
      creator:         user,
      status:          "pending",
    )
  end

  def build_forum_topic
    ForumTopic.new(
      title:                    self.class.topic_title(antecedent_name, consequent_name),
      creator:                  user,
      original_post_attributes: {
        body: "Reason: #{reason}",
      },
      category_id:              AdminConfig.instance.alias_and_implication_forum_category,
    )
  end

  def validate_tag_relationship
    tag_relationship = @tag_relationship || build_tag_relationship

    if tag_relationship.invalid?
      errors.merge!(tag_relationship.errors)
    end
  end

  def validate_forum_topic
    return if skip_forum
    return errors.add(:forum_topic_id, "is invalid") if @forum_topic_id.present? && @forum_topic.blank?
    ft = @forum_topic || build_forum_topic
    if ft.invalid?
      errors.add(:base, ft.errors.full_messages.join("; "))
    end
  end

  def skip_forum=(value)
    @skip_forum = value.to_s.truthy?
  end
end
