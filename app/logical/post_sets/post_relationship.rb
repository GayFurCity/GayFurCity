# frozen_string_literal: true

module PostSets
  class PostRelationship < PostSets::Post
    attr_reader(:parent, :children)

    def initialize(parent_id, current_user:, **options)
      @want_parent = options[:want_parent]
      @parent = ::Post.where("id = ?", parent_id)
      @children = ::Post.where("parent_id = ?", parent_id).order(:id)
      if options[:include_deleted]
        super("parent:#{parent_id} status:any", current_user: current_user)
      else
        @children = @children.where("is_deleted = ?", false)
        super("parent:#{parent_id}", current_user: current_user)
      end
    end

    def posts
      return @parent if @want_parent
      @children
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end
  end
end
