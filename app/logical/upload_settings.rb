# frozen_string_literal: true

class UploadSettings
  include(ActiveModel::Serializers::JSON)

  ATTRIBUTES = %i[compact_mode safe_site post_tags upload_tags recent_tags allow_locked_tags allow_rating_lock allow_upload_as_pending allow_upload_as_in_progress max_file_size max_file_size_map max_file_size_per_request].freeze

  attr_accessor(:user, :post)

  def initialize(user, post = nil)
    @user = user
    @post = post
  end

  def compact_mode
    user.compact_uploader?
  end

  def safe_site
    user.safe_mode?
  end

  def post_tags
    return if post.nil?
    "#{post.presenter.split_tag_list_text} "
  end

  def upload_tags
    user.presenter.favorite_tags_with_types
  end

  def recent_tags
    user.presenter.recent_tags_with_types
  end

  def allow_locked_tags
    user.policy_for(Upload).can_use_attribute?(:locked_tags)
  end

  def allow_rating_lock
    user.policy_for(Upload).can_use_attribute?(:locked_rating)
  end

  def allow_upload_as_pending
    user.policy_for(Upload).can_use_attribute?(:as_pending)
  end

  def allow_upload_as_in_progress
    user.policy_for(Upload).can_use_attribute?(:as_in_progress)
  end

  def max_file_size
    Config.instance.max_file_size * 1.megabyte
  end

  def max_file_size_map
    Config.instance.max_file_sizes.transform_values { |v| v * 1.megabyte }
  end

  def max_file_size_per_request
    Config.instance.max_upload_per_request * 1.megabyte
  end

  def serializable_hash(*)
    { user_id: user.id }.merge(ATTRIBUTES.index_with { |attr| send(attr) })
  end
end
