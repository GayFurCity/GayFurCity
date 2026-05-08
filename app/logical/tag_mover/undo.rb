# frozen_string_literal: true

class TagMover
  class Undo
    attr_reader(:undo_data, :user, :request, :applied)

    def initialize(undo_data, user: User.system, request: nil)
      @undos = undo_data.map { |undo| [undo.first.to_sym, undo.second.transform_keys(&:to_sym)] }
      @user = user
      @request = request
      @applied = []
    end

    def undo!
      @undos.each do |undo|
        case undo.first
        when :update_tag_category
          success = undo_update_tag_category!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_artist_name
          success = undo_update_artist_name!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_wiki_page_title
          success = undo_update_wiki_page_title!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_tag_alias_consequent_name
          success = undo_update_tag_alias_consequent_name!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :destroy_tag_alias
          success = undo_destroy_tag_alias!(undo.second[:antecedent_name], undo.second[:consequent_name], undo.second[:status])
        when :update_tag_implication_consequent_name
          success = undo_update_tag_implication_consequent_name!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_tag_implication_antecedent_name
          success = undo_update_tag_implication_antecedent_name!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :destroy_tag_implication
          success = undo_destroy_tag_implication!(undo.second[:antecedent_name], undo.second[:consequent_name], undo.second[:status])
        when :update_post_tags
          success = undo_update_post_tags!(undo.second[:ids], undo.second[:old], undo.second[:new])
        when :update_post_locked_tags
          success = undo_update_post_locked_tags!(undo.second[:ids], undo.second[:old], undo.second[:new])
        when :update_pool_description
          success = undo_rewrite_pool_description!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_wiki_page_body
          success = undo_rewrite_wiki_page_body!(undo.second[:id], undo.second[:old], undo.second[:new])
        when :update_blacklists
          success = undo_update_blacklists!(undo.second[:old], undo.second[:new])
        when :update_tag_follower
          success = undo_update_tag_follower!(undo.second[:id], undo.second[:old], undo.second[:new])
        else
          raise(NotImplementedError, "Not sure how to undo #{undo.first}")
        end
        applied << undo if success
      end
    end

    def undo_update_tag_category!(id, old, new)
      tag = Tag.find_by(id: id)
      return false unless tag && tag.category == new
      case request
      when TagAlias
        reason = "undo: alias ##{request.id} (#{request.antecedent_name} -> #{request.consequent_name})"
      when TagImplication
        reason = "undo: implication ##{request.id} (#{request.antecedent_name} -> #{request.consequent_name})"
      when BulkUpdateRequest
        reason = "undo: bulk update request ##{request.id} (#{request.antecedent_name} -> #{request.consequent_name})"
      else
        reason = "undo tag move"
      end

      tag.update!(category: old, reason: reason)
      true
    end

    def undo_update_artist_name!(id, old, new)
      artist = Artist.find_by(id: id)
      return false unless artist && artist.name == new
      artist.other_names -= [old]
      artist.name = old
      artist.updater = user
      artist.save!
      true
    end

    def undo_update_wiki_page_title!(id, old, new)
      wiki_page = WikiPage.find_by(id: id)
      return false unless wiki_page && wiki_page.title == new
      wiki_page.title = old
      wiki_page.updater = user
      wiki_page.save!
      true
    end

    def undo_update_post_tags!(ids, old, new)
      user = User.system
      Post.without_timeout do
        Post.where(id: ids).find_each do |post|
          next unless post.has_tag?(new)
          post.with_lock do
            post.automated_edit = true
            post.updater = user
            post.remove_tag(new)
            post.add_tag(old)
            post.save!
          end
        end
      end
      true
    end

    def undo_update_post_locked_tags!(ids, old, new)
      user = User.system
      Post.without_timeout do
        Post.where(id: ids).find_each do |post|
          post.with_lock do
            fixed_tags = TagAlias.to_aliased_query(post.locked_tags, overrides: { new => old })
            post.automated_edit = true
            post.updater = user
            post.locked_tags = fixed_tags
            post.save!
          end
        end
      end
      true
    end

    def undo_update_tag_alias_consequent_name!(id, old, new)
      tag_alias = TagAlias.find_by(id: id)
      return false unless tag_alias && tag_alias.consequent_name == new && !TagAlias.duplicate_relevant.exists?(antecedent_name: tag_alias.antecedent_name, consequent_name: old)
      tag_alias.update!(consequent_name: old, updater: user)
      true
    end

    def undo_destroy_tag_alias!(antecedent_name, consequent_name, status)
      duplicate = TagAlias.duplicate_relevant.find_by(antecedent_name: antecedent_name, consequent_name: consequent_name)
      return false if duplicate || TagAlias.exists?(antecedent_name: antecedent_name, consequent_name: consequent_name, status: status)
      TagAlias.create!(antecedent_name: antecedent_name, consequent_name: consequent_name, status: status, creator: user)
      true
    end

    def undo_update_tag_implication_antecedent_name!(id, old, new)
      tag_implication = TagImplication.find_by(id: id)
      return false unless tag_implication && tag_implication.antecedent_name == new && !TagImplication.duplicate_relevant.exists?(antecedent_name: old, consequent_name: tag_implication.consequent_name)
      tag_implication.update!(antecedent_name: old, updater: user)
      true
    end

    def undo_update_tag_implication_consequent_name!(id, old, new)
      tag_implication = TagImplication.find_by(id: id)
      return false unless tag_implication && tag_implication.consequent_name == new && !TagImplication.duplicate_relevant.exists?(antecedent_name: tag_implication.antecedent_name, consequent_name: old)
      tag_implication.update!(consequent_name: old, updater: user)
      true
    end

    def undo_destroy_tag_implication!(antecedent_name, consequent_name, status)
      duplicate = TagImplication.duplicate_relevant.find_by(antecedent_name: antecedent_name, consequent_name: consequent_name)
      return false if duplicate || TagImplication.exists?(antecedent_name: antecedent_name, consequent_name: consequent_name, status: status)
      TagImplication.create!(antecedent_name: antecedent_name, consequent_name: consequent_name, status: status, creator: user)
      true
    end

    def undo_update_blacklists!(old, new)
      User.rewrite_blacklists!(new, old)
      true
    end

    def undo_rewrite_wiki_page_body!(id, old, new)
      wiki_page = WikiPage.find_by(id: id)
      return false unless wiki_page
      wiki_page.update!(body: DTextHelper.rewrite_wiki_links(wiki_page.body, new, old), updater: user)
      true
    end

    def undo_rewrite_pool_description!(id, old, new)
      pool = Pool.find_by(id: id)
      return false unless pool
      pool.update!(description: DTextHelper.rewrite_wiki_links(pool.description, new, old), updater: user)
      true
    end

    def undo_update_tag_follower!(id, old, new)
      follower = TagFollower.find_by(id: id)
      old_tag = Tag.find_by(name: old)
      new_tag = Tag.find_by(name: new)
      return false unless follower && follower.tag == new_tag
      follower.tag = old_tag
      follower.save!
      old_tag.updater = user
      new_tag.updater = user
      old_tag.increment!(:follower_count)
      new_tag.decrement!(:follower_count)
      true
    end
  end
end
