# frozen_string_literal: true

class UserVote < ApplicationRecord
  class Error < StandardError; end

  self.abstract_class = true

  def self.inherited(child_class)
    super
    return if child_class.name.starts_with?("Lockable") # We can't check for abstract here, it hasn't been set yet
    child_class.class_eval do
      belongs_to(model_type)
      belongs_to_user(:user, ip: true, counter_cache: "#{child_class.name.underscore}_count")
    end
  end

  # PostVote => :post
  def self.model_type
    model_name.singular.delete_suffix("_vote").to_sym
  end

  def self.model
    name.delete_suffix("Vote").constantize
  end

  def self.vote_types
    [%w[Downvote -1 text-red], %w[Upvote 1 text-green]]
  end

  def is_positive?
    score == 1
  end

  def is_negative?
    score == -1
  end

  def vote_type
    case score
    when 1
      "up"
    when -1
      "down"
    else
      raise
    end
  end

  def vote_display
    self.class.vote_types.to_h { |type, value, klass| [value, %(<span class="#{klass}">#{type.titleize}</span>)] }[score.to_s]
  end

  module SearchMethods
    def query_dsl
      super
        .field(:"#{model_type}_id", multi: true)
        .field(:ip_addr, :user_ip_addr)
        .field(:score)
        .custom(:timeframe, ->(q, v) { q.where.gteq(updated_at: v.to_i.days.ago) })
        .custom(:duplicates_only, method(:duplicates_only_query).to_proc)
        .field(:"#{model_type}_creator_id", :"#{model.table_name}.#{model_creator_column}_id") { |q| q.joins(model_type) }
        .custom(:"#{model_type}_creator_name", method(:model_creator_name_query).to_proc)
        .association(:user)
        .association(model_type)
    end

    def model_creator_name_query(q, value)
      return q if value.blank?

      user_table = User.arel_table.alias("#{model_type}_creator_users")
      model_table = model.arel_table
      join = model_table.join(user_table)
                        .on(user_table[:id].eq(model_table[:"#{model_creator_column}_id"]))
                        .join_sources

      q.joins(model_type).joins(join).where(user_table[:name].eq(value))
    end

    def duplicates_only_query(q, value, user, params)
      return unless value.to_s.truthy?
      subselect = search(params.except("duplicates_only"), user).select(:user_ip_addr).group(:user_ip_addr).having("count(user_ip_addr) > 1").reorder("")
      q.where(user_ip_addr: subselect)
    end

    def apply_order(params)
      order_with({
        ip_addr: { "#{table_name}.user_ip_addr": :asc },
      }, params[:order])
    end
  end

  extend(SearchMethods)

  def visible?(user)
    user.is_moderator? || user_id == user.id
  end

  def self.controller
    {
      "CommentVote"   => "comments/votes",
      "ForumPostVote" => "forums/posts/votes",
      "PostVote"      => "posts/votes",
    }.fetch(name)
  end
end
