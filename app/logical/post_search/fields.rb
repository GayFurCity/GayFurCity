# frozen_string_literal: true

# The single source of truth for the /posts/search advanced search form: which metatags it
# exposes, grouped into sections, and how each should be rendered. Mirrors AdminConfig::Fields'
# category DSL. PostSearch::QueryBuilder turns submitted field values into a tags string;
# PostSearch::FormParser does the reverse, for pre-filling the form from an existing search.
module PostSearch
  module Fields
    mattr_accessor(:fields, default: [])
    mattr_accessor(:categories, default: [])

    Field = Struct.new(:type, :category, :metatag, :name, :hint, :negatable, :options, :input_options, keyword_init: true) do
      def field_name
        "search[#{metatag}]"
      end

      def mode_field_name
        "search[#{metatag}_mode]"
      end

      def dom_id
        "search_#{metatag}"
      end
    end

    module Methods
      def add_field(type, metatag, category:, name: metatag.to_s.titleize, hint: nil, negatable: false, options: nil, input_options: {})
        fields << Field.new(type: type, category: category, metatag: metatag, name: name, hint: hint, negatable: negatable, options: options, input_options: input_options)
      end

      def add_text_field(metatag, **)
        add_field(:text, metatag, **)
      end

      def add_select_field(metatag, options, **)
        add_field(:select, metatag, options: options, **)
      end

      def add_boolean_field(metatag, **)
        add_field(:boolean, metatag, **)
      end

      # Same value syntax as :text (ParseValue.range: "100", ">100", ">=100", "<100",
      # "<=100", "100..200", "100..", "..200") - just rendered with an operator selector
      # instead of asking the user to type the operator themselves.
      def add_range_field(metatag, **)
        add_field(:range, metatag, **)
      end

      def category(name, &block)
        categories << name
        return if block.nil?

        mod = Module.new do
          module_function

          def add_field(*, **)
            PostSearch::Fields.add_field(*, category: category, **)
          end

          def add_text_field(*, **)
            PostSearch::Fields.add_text_field(*, category: category, **)
          end

          def add_select_field(*, **)
            PostSearch::Fields.add_select_field(*, category: category, **)
          end

          def add_boolean_field(*, **)
            PostSearch::Fields.add_boolean_field(*, category: category, **)
          end

          def add_range_field(*, **)
            PostSearch::Fields.add_range_field(*, category: category, **)
          end
        end
        mod.module_eval { define_singleton_method(:category) { name } }
        mod.module_eval(&block)
      end

      def fields_for(category_name)
        fields.select { |f| f.category == category_name }
      end

      def find(metatag)
        fields.find { |f| f.metatag == metatag.to_sym }
      end
    end
    extend(Methods)

    RATING_OPTIONS = [%w[Safe s], %w[Questionable q], %w[Explicit e]].freeze
    STATUS_OPTIONS = [%w[Active active], %w[Pending pending], %w[Flagged flagged], %w[Deleted deleted], %w[Appealed appealed],
                      %w[Unlisted unlisted], ["In Progress", "in_progress"], %w[Modqueue modqueue], %w[Any any], %w[All all],].freeze
    LOCKED_OPTIONS = [%w[Rating rating], %w[Note note], %w[Status status]].freeze
    CHILD_OPTIONS = [%w[Any any], %w[None none]].freeze
    FILETYPE_OPTIONS = Post::EXTENSIONS.map { |ext| [ext.upcase, ext] }.freeze
    ORDER_OPTIONS = TagQuery::ORDER_METATAGS.map { |o| [o.tr("_", " ").titleize, o] }.freeze

    category("Rating & Status") do
      add_select_field(:rating, RATING_OPTIONS, negatable: true, hint: "Leave blank for any rating")
      add_select_field(:status, STATUS_OPTIONS, hint: "Defaults to not deleted or unlisted")
      add_select_field(:locked, LOCKED_OPTIONS, negatable: true, name: "Locked Field")
      add_boolean_field(:ratinglocked)
      add_boolean_field(:notelocked)
      add_boolean_field(:statuslocked)
    end

    category("Ordering & Paging") do
      add_select_field(:order, ORDER_OPTIONS, hint: "Defaults to newest first")
      add_text_field(:limit, name: "Posts Per Page")
    end

    category("Dimensions & Files") do
      add_range_field(:width, negatable: true)
      add_range_field(:height, negatable: true)
      add_range_field(:mpixels, negatable: true, name: "Megapixels")
      add_range_field(:ratio, negatable: true, hint: "e.g. 16:9")
      add_range_field(:filesize, negatable: true, hint: "e.g. 1mb, 500kb")
      add_range_field(:duration, negatable: true, hint: "in seconds")
      add_range_field(:framecount, negatable: true)
      add_select_field(:filetype, FILETYPE_OPTIONS, negatable: true)
      add_text_field(:md5, name: "MD5")
    end

    category("Scores & Counts") do
      add_range_field(:score, negatable: true)
      add_range_field(:favcount, negatable: true, name: "Favorite Count")
      add_range_field(:views, negatable: true)
      add_range_field(:tagcount, negatable: true, name: "Tag Count")
      add_range_field(:comment_count, negatable: true, name: "Comment Count")
      add_range_field(:change, negatable: true, name: "Change Sequence")

      TagCategory::CATEGORIZED_LIST.each do |cat|
        category_obj = TagCategory.get(cat)
        short_name = category_obj.aliases.first || cat
        add_range_field(:"#{short_name}tags", negatable: true, name: "#{category_obj.title} Tag Count")
      end
    end

    category("Dates") do
      add_text_field(:date, negatable: true, hint: "e.g. 2024-01-01, 2024-01-01..2024-02-01")
      add_text_field(:age, negatable: true, hint: "e.g. <1week, >3months")
    end

    category("Users") do
      add_text_field(:user, negatable: true, name: "Uploader", hint: "username, or any/none")
      add_text_field(:approver, negatable: true, hint: "username, or any/none")
      add_text_field(:disapprover, negatable: true, hint: "username, or any/none")
      add_text_field(:commenter, negatable: true, hint: "username, or any/none")
      add_text_field(:noter, negatable: true, hint: "username, or any/none")
      add_text_field(:noteupdater, negatable: true, hint: "username, or any/none")
      add_text_field(:favoritedby, negatable: true, name: "Favorited By", hint: "username, or any/none")
      add_text_field(:upvote, negatable: true, name: "Upvoted By")
      add_text_field(:downvote, negatable: true, name: "Downvoted By")
      add_text_field(:voted, negatable: true, name: "Voted On By")
      add_text_field(:flagger, negatable: true, hint: "username, or any/none")
      add_text_field(:deletedby, negatable: true, name: "Deleted By", hint: "username, or any/none")
      add_range_field(:disapprovals, negatable: true, name: "Disapproval Count")
    end

    category("Relations") do
      add_range_field(:id, negatable: true, name: "Post ID")
      add_text_field(:parent, negatable: true, hint: "parent post id, or any/none")
      add_select_field(:child, CHILD_OPTIONS, hint: "has children")
      add_text_field(:pool, negatable: true, hint: "pool name/id, or any/none")
      add_text_field(:set, negatable: true, hint: "set name/id, or any/none")
    end

    category("Content") do
      add_text_field(:source, negatable: true)
      add_text_field(:description, negatable: true)
      add_text_field(:note, negatable: true)
      add_text_field(:delreason, negatable: true, name: "Deletion Reason")
      add_text_field(:qtags, negatable: true, name: "Question Tags")
      add_boolean_field(:hassource, name: "Has Source")
      add_boolean_field(:hasdescription, name: "Has Description")
      add_boolean_field(:isparent, name: "Is Parent")
      add_boolean_field(:ischild, name: "Is Child")
      add_boolean_field(:inpool, name: "In A Pool")
      add_boolean_field(:pending_replacements, name: "Has Pending Replacements")
      add_boolean_field(:artverified, name: "Verified Artist Upload")
    end

    category("Misc") do
      add_text_field(:randseed, name: "Random Seed")
    end
  end
end
