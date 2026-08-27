# frozen_string_literal: true

class TagMover
  attr_reader(:old_tag, :new_tag, :user, :request, :undos)

  def initialize(old_name, new_name, user: User.system, request: nil, create_tags: true)
    @old_tag = create_tags ? Tag.find_or_create_by_name(old_name, user: user) : (Tag.find_by_normalized_name(old_name) || Tag.new(name: Tag.normalize_name(old_name)))
    @new_tag = create_tags ? Tag.find_or_create_by_name(new_name, user: user) : (Tag.find_by_normalized_name(new_name) || Tag.new(name: Tag.normalize_name(new_name)))
    @user = user
    @request = request
    @undos = []
  end

  def move!
    update_tag_category!
    move_artist!
    move_wiki!
    move_posts!
    update_locked_tags!
    move_aliases!
    move_implications!
    update_blacklists!
    rewrite_wiki_links!
    update_followers!
  end

  def update_tag_category!
    tag, category = tag_category_update
    if tag.present? && category.present?
      case request
      when TagAlias
        reason = "alias ##{request.id} (#{old_tag.name} -> #{new_tag.name})"
      when TagImplication
        reason = "implication ##{request.id} (#{old_tag.name} -> #{new_tag.name})"
      when BulkUpdateRequest
        reason = "bulk update request ##{request.id} (#{old_tag.name} -> #{new_tag.name})"
      when BulkUpdateRequestCommands::Rename
        reason = "rename (#{old_tag.name} -> #{new_tag.name})"
      else
        reason = "tag move (#{old_tag.name} -> #{new_tag.name})"
      end
      old = tag.category
      tag.update!(category: category, reason: reason, updater: user)
      undos << [:update_tag_category, { id: tag.id, old: old, new: category }]
    end
  end

  def tag_category_update
    if !old_tag.is_locked? && old_tag.general? && !new_tag.general? && old_tag.post_count < AdminConfig.instance.alias_category_change_cutoff
      return [old_tag, new_tag.category]
    elsif !new_tag.is_locked? && new_tag.general? && !old_tag.general? && new_tag.post_count < AdminConfig.instance.alias_category_change_cutoff
      return [new_tag, old_tag.category]
    end
    [nil, nil]
  end

  def move_artist!
    return unless old_tag.artist? && old_artist.present?

    if new_artist.nil?
      undos << [:update_artist_name, { id: old_artist.id, old: old_tag.name, new: new_tag.name }]
      old_artist.name = new_tag.name
      old_artist.other_names += [old_tag.name]
      old_artist.updater = user
      old_artist.save!
    else
      # we consider merging undoable
      merge_artists!
    end
  end

  def merge_artists!
    ApplicationRecord.transaction do
      [old_artist, new_artist, new_artist&.wiki_page].compact_blank.sort_by(&:id).each(&:lock!)

      new_artist.other_names = [*old_artist.other_names, old_artist.name]
      new_artist.url_string += "\n#{old_artist.url_string}"
      new_artist.is_locked = old_artist.is_locked?
      new_artist.linked_user_id ||= old_artist.linked_user_id
      new_artist.notes ||= old_artist.notes
      new_artist.updater = user
      new_artist.save!

      old_artist.other_names = [new_artist.name]
      old_artist.url_string = ""
      old_artist.linked_user_id = nil
      old_artist.updater = user
      old_artist.save!
    end
  end

  def move_wiki!
    return if old_wiki.blank?

    if new_wiki.nil?
      undos << [:update_wiki_page_title, { id: old_wiki.id, old: old_tag.name, new: new_tag.name }]
      old_wiki.update!(title: new_tag.name, updater: user)
    else
      # we consider merging undoable
      merge_wikis!
    end
  end

  def merge_wikis!
    ApplicationRecord.transaction do
      [old_wiki, new_wiki].sort_by(&:id).each(&:lock!)

      new_wiki.body = old_wiki.body if new_wiki.body.blank?
      new_wiki.parent = old_wiki.parent if old_wiki.parent.present?
      new_wiki.protection_level = old_wiki.protection_level
      new_wiki.updater = user
      new_wiki.save!

      old_wiki.parent = new_wiki if old_wiki.parent.blank?
      old_wiki.updater = user
      old_wiki.save!
    end
  end

  def move_posts!
    user = User.system
    Post.without_timeout do
      post_ids = []
      Post.sql_raw_tag_match(old_tag.name).find_each do |post|
        post_ids << post.id
        post.with_lock do
          post.automated_edit = true
          post.updater = user
          post.remove_tag(old_tag.name)
          post.add_tag(new_tag.name)
          post.save!
        end
      end
      undos << [:update_post_tags, { ids: post_ids, old: old_tag.name, new: new_tag.name }] if post_ids.present?
    end
  end

  def update_locked_tags!
    user = User.system
    Post.without_timeout do
      post_ids = []
      Post.where_ilike(:locked_tags, "*#{old_tag.name}*").find_each(batch_size: 50) do |post|
        post_ids << post.id
        post.with_lock do
          fixed_tags = TagAlias.to_aliased_query(post.locked_tags)
          post.automated_edit = true
          post.updater = user
          post.locked_tags = fixed_tags
          post.save!
        end
      end
      undos << [:update_post_locked_tags, { ids: post_ids, old: old_tag.name, new: new_tag.name }] if post_ids.present?
    end
  end

  def move_aliases!
    old_tag.consequent_aliases.find_each do |tag_alias|
      tag_alias.updater = user
      tag_alias.consequent_name = new_tag.name
      success = tag_alias.save
      if success
        undos << [:update_tag_alias_consequent_name, { id: tag_alias.id, old: old_tag.name, new: new_tag.name }]
      elsif tag_alias.errors.full_messages.join("; ") =~ /Cannot alias a tag to itself/
        tag_alias.destroy
        # consequent_name was already mutated to new_tag.name above, so use old_tag.name (its
        # original value) instead - otherwise the undo entry records a self-referential alias.
        undos << [:destroy_tag_alias, { antecedent_name: tag_alias.antecedent_name, consequent_name: old_tag.name, status: tag_alias.status }]
      end
    end
  end

  def move_implications!
    old_tag.antecedent_implications.find_each do |tag_implication|
      tag_implication.updater = user
      tag_implication.antecedent_name = new_tag.name
      success = tag_implication.save
      if success
        undos << [:update_tag_implication_antecedent_name, { id: tag_implication.id, old: old_tag.name, new: new_tag.name }]
      elsif tag_implication.errors.full_messages.join("; ") =~ /Cannot implicate a tag to itself/
        tag_implication.destroy
        # antecedent_name was already mutated to new_tag.name above, so use old_tag.name (its
        # original value) instead - otherwise the undo entry records a self-referential implication.
        undos << [:destroy_tag_implication, { antecedent_name: old_tag.name, consequent_name: tag_implication.consequent_name, status: tag_implication.status }]
      end
    end

    old_tag.consequent_implications.find_each do |tag_implication|
      tag_implication.updater = user
      tag_implication.consequent_name = new_tag.name
      success = tag_implication.save
      if success
        undos << [:update_tag_implication_consequent_name, { id: tag_implication.id, old: old_tag.name, new: new_tag.name }]
      elsif tag_implication.errors.full_messages.join("; ") =~ /Cannot implicate a tag to itself/
        tag_implication.destroy
        # consequent_name was already mutated to new_tag.name above, so use old_tag.name (its
        # original value) instead - otherwise the undo entry records a self-referential implication.
        undos << [:destroy_tag_implication, { antecedent_name: tag_implication.antecedent_name, consequent_name: old_tag.name, status: tag_implication.status }]
      end
    end
  end

  def update_blacklists!
    User.rewrite_blacklists!(old_tag.name, new_tag.name)
    undos << [:update_blacklists, { old: old_tag.name, new: new_tag.name }]
  end

  def rewrite_wiki_links!
    [WikiPage, Pool].each do |model|
      field = { WikiPage => :body, Pool => :description }[model]
      model.linked_to(old_tag.name).find_each do |linked|
        undos << [:"update_#{model.name.underscore}_#{field}", { id: linked.id, old: old_tag.name, new: new_tag.name }]
        linked.update!(field => DTextHelper.rewrite_wiki_links(linked.public_send(field), old_tag.name, new_tag.name), :updater => user)
      end
    end
  end

  def update_followers!
    return if old_tag.followers.empty?
    count = 0
    old_tag.followers.each do |follower|
      count += 1
      undos << [:update_tag_follower, { id: follower.id, old: old_tag.name, new: new_tag.name }]
      follower.update!(tag: new_tag)
    end
    new_tag.update!(follower_count: count, updater: user)
    old_tag.update!(follower_count: 0, updater: user)
  end

  def old_wiki
    old_tag.wiki_page
  end

  def new_wiki
    new_tag.wiki_page
  end

  def old_artist
    old_tag.artist
  end

  def new_artist
    new_tag.artist
  end
end
