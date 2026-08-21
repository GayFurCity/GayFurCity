# frozen_string_literal: true

class TagRelationship < ApplicationRecord
  self.abstract_class = true

  SUPPORT_HARD_CODED = true

  belongs_to(:forum_post, optional: true)
  belongs_to(:forum_topic, optional: true)
  belongs_to(:antecedent_tag, class_name: "Tag", foreign_key: "antecedent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(antecedent_name, user: creator) })
  belongs_to(:consequent_tag, class_name: "Tag", foreign_key: "consequent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(consequent_name, user: creator) })
  before_validation(:normalize_names)
  validates(:status, format: { with: /\A(active|deleted|pending|processing|queued|retired|error: .*)\Z/ })
  validates(:creator_id, :antecedent_name, :consequent_name, presence: true)
  validates(:creator, presence: { message: "must exist" }, if: -> { creator_id.present? })
  validates(:approver, presence: { message: "must exist" }, if: -> { approver_id.present? })
  validates(:forum_topic, presence: { message: "must exist" }, if: -> { forum_topic_id.present? })
  validate(:validate_creator_is_not_limited, on: :create)
  validates(:antecedent_name, tag_name: { disable_ascii_check: true }, if: :antecedent_name_changed?)
  validates(:consequent_name, tag_name: true, if: :consequent_name_changed?)
  validate(:antecedent_and_consequent_are_different)
  after_save(:create_mod_action)

  scope(:active, -> { approved })
  scope(:approved, -> { where(status: %w[active processing queued]) })
  scope(:deleted, -> { where(status: "deleted") })
  scope(:not_deleted, -> { where.not(status: "deleted") })
  scope(:pending, -> { where(status: "pending") })
  scope(:retired, -> { where(status: "retired") })
  scope(:duplicate_relevant, -> { where(status: %w[active processing queued pending]) })
  scope(:errored, -> { where.ilike(status: "error: *") })

  def normalize_names
    self.antecedent_name = antecedent_name.downcase.tr(" ", "_")
    self.consequent_name = consequent_name.downcase.tr(" ", "_")
  end

  def validate_creator_is_not_limited
    allowed = creator.can_suggest_tag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def is_approved?
    status.in?(%w[active processing queued])
  end

  def is_retired?
    status == "retired"
  end

  def is_deleted?
    status == "deleted"
  end

  def is_pending?
    status == "pending"
  end

  def is_active?
    status == "active"
  end

  def is_errored?
    status =~ /\Aerror:/
  end

  def approvable_by?(user)
    return false unless is_pending? && user.can_manage_aibur?
    return false unless user.is_owner? || !(consequent_tag&.artist&.is_dnp? || antecedent_tag&.artist&.is_dnp?)
    return false unless user.is_admin? || creator_id != user.id
    Config.get_user(:tag_change_request_update_limit, user) >= estimate_update_count
  end

  def rejectable_by?(user)
    return true if !is_deleted? && user.can_manage_aibur?
    is_pending? && creator_id == user.id
  end

  def editable_by?(user)
    is_pending? && user.can_manage_aibur?
  end

  module SearchMethods
    def status_matches(status)
      status = status.downcase

      if status == "approved"
        where(status: %w[active processing queued])
      else
        where(status: status)
      end
    end

    def name_matches(name)
      where.like(antecedent_name: Tag.normalize_name(name)).or(
        where.like(consequent_name: Tag.normalize_name(name)),
      )
    end

    def pending_first
      # unknown statuses are sorted first
      order(case_order(:status, [nil, "queued", "processing", "pending", "active", "deleted", "retired"]), "#{table_name}.id": :desc)
    end

    # Use stable join aliases for filters and ordering that reference tag columns directly.
    # Rails chooses different aliases depending on the combination of joined associations.
    def join_antecedent
      join_as(:antecedent_tag, "antecedent_tag", Arel::Nodes::OuterJoin)
    end

    def join_consequent
      join_as(:consequent_tag, "consequent_tag", Arel::Nodes::OuterJoin)
    end

    def default_order
      pending_first
    end

    def apply_order(params)
      order_with({
        created_at:      -> { order(arel(:created_at).desc.nulls_last, "#{table_name}.id": :desc) },
        created_at_asc:  -> { order(arel(:created_at).asc.nulls_last, "#{table_name}.id": :desc) },
        created_at_desc: -> { order(arel(:created_at).desc.nulls_last, "#{table_name}.id": :desc) },
        updated_at:      -> { order(arel(:updated_at).desc.nulls_last, "#{table_name}.id": :desc) },
        updated_at_asc:  -> { order(arel(:updated_at).asc.nulls_last, "#{table_name}.id": :desc) },
        updated_at_desc: -> { order(arel(:updated_at).desc.nulls_last, "#{table_name}.id": :desc) },
        name:            { "#{table_name}.antecedent_name": :asc, "#{table_name}.consequent_name": :asc },
        tag_count:       -> { join_consequent.order("consequent_tag.post_count": :desc, "#{table_name}.id": :desc) },
        tag_count_asc:   -> { join_consequent.order("consequent_tag.post_count": :asc, "#{table_name}.id": :desc) },
        tag_count_desc:  -> { join_consequent.order("consequent_tag.post_count": :desc, "#{table_name}.id": :desc) },
        rating:          -> { left_joins(:forum_post).order("forum_posts.percentage_score": :desc, "#{table_name}.id": :desc) },
        rating_asc:      -> { left_joins(:forum_post).order("forum_posts.percentage_score": :asc, "#{table_name}.id": :desc) },
        rating_desc:     -> { left_joins(:forum_post).order("forum_posts.percentage_score": :desc, "#{table_name}.id": :desc) },
        score:           -> { left_joins(:forum_post).order("forum_posts.total_score": :desc, "#{table_name}.id": :desc) },
        score_asc:       -> { left_joins(:forum_post).order("forum_posts.total_score": :asc, "#{table_name}.id": :desc) },
        score_desc:      -> { left_joins(:forum_post).order("forum_posts.total_score": :desc, "#{table_name}.id": :desc) },
      }, params[:order])
    end

    def query_dsl
      super
        .field(:antecedent_name, multi: true)
        .field(:consequent_name, multi: true)
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .custom(:antecedent_tag_category, ->(q, v) { q.join_antecedent.where("antecedent_tag.category": v.split(",").map(&:to_i).compact_blank.first(Config.instance.max_multi_count)) })
        .custom(:consequent_tag_category, ->(q, v) { q.join_consequent.where("consequent_tag.category": v.split(",").map(&:to_i).compact_blank.first(Config.instance.max_multi_count)) })
        .custom(:name_matches, ->(q, v) { q.where.like(antecedent_name: v).or(q.where.like(consequent_name: v)) })
        .custom(:status, ->(q, v) { q.status_matches(v) })
        .association(:updater)
        .association(:creator)
        .association(:approver)
    end
  end

  module MessageMethods
    def relationship
      # "TagAlias" -> "tag alias", "TagImplication" -> "tag implication"
      self.class.name.underscore.tr("_", " ")
    end

    def approval_message(approver)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been approved by @#{approver.name}."
    end

    def failure_message(error = nil)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} failed during processing. Reason: #{error}"
    end

    def reject_message(rejector)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been rejected by @#{rejector.name}."
    end

    def retirement_message
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been retired."
    end

    def forum_link
      "(forum ##{forum_post.id})" if forum_post.present?
    end
  end

  concerning(:EmbeddedText) do
    class_methods do
      def embedded_pattern
        raise(NotImplementedError)
      end
    end
  end

  def antecedent_and_consequent_are_different
    if antecedent_name == consequent_name
      if is_a?(TagAlias)
        errors.add(:base, "Cannot alias a tag to itself")
      elsif is_a?(TagImplication)
        errors.add(:base, "Cannot implicate a tag to itself")
      else
        errors.add(:base, "Antecedent and consequent tags must be different")
      end
    end
  end

  def estimate_update_count
    Post.system_count(antecedent_name, enable_safe_mode: false, include_deleted: true)
  end

  def update_posts(user = User.system)
    Post.without_timeout do
      Post.sql_raw_tag_match(antecedent_name).find_each do |post|
        post.with_lock do
          post.automated_edit = true
          post.updater = user
          post.tag_string += " "
          post.save!
        end
      end
    end
  end

  def create_mod_action
    name = self.class.name.delete_prefix("Tag").underscore.gsub(" ", " ")
    desc = %("tag #{name} ##{id}":[#{Routes.public_send("tag_#{name}_path", self)}]: [[#{antecedent_name}]] -> [[#{consequent_name}]])

    if previously_new_record?
      ModAction.log!(creator, :"tag_#{name}_create", self, "#{name}_desc": desc)
    else
      # format the changes hash more nicely.
      change_desc = saved_changes.except(:updated_at).map do |attribute, values|
        next unless %w[antecedent_name consequent_name status approver_id reason].include?(attribute)
        old = values[0]
        new = values[1]
        if old.nil?
          %(set #{attribute} to "#{new}")
        else
          %(changed #{attribute} from "#{old}" to "#{new}")
        end
      end.join("\n")

      return if change_desc.blank?
      ModAction.log!(updater, :"tag_#{name}_update", self, "#{name}_desc": desc, change_desc: change_desc)
    end
  end

  extend(SearchMethods)
  include(MessageMethods)

  def self.available_includes
    %i[antecedent_tag approver consequent_tag creator forum_post forum_topic]
  end
end
