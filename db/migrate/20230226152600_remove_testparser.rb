# frozen_string_literal: true

class RemoveTestparser < ActiveRecord::Migration[7.0]
  def up
    execute("DROP TRIGGER IF EXISTS trigger_posts_on_tag_index_update ON posts")
    remove_column(:posts, :tag_index)

    execute("DROP TEXT SEARCH CONFIGURATION IF EXISTS danbooru")
    execute("DROP TEXT SEARCH PARSER IF EXISTS testparser")
    %i[testprs_start testprs_lextype testprs_getlexeme testprs_end].each do |function|
      execute("DROP FUNCTION IF EXISTS #{function}")
    end
  end

  def down
    testparser_exists = ActiveRecord::Base.connection.select_value("SELECT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'test_parser') as exists")

    if testparser_exists
      execute("CREATE FUNCTION public.testprs_end(internal) RETURNS void LANGUAGE c STRICT AS '$libdir/test_parser', 'testprs_end'")
      execute("CREATE FUNCTION public.testprs_getlexeme(internal, internal, internal) RETURNS internal LANGUAGE c STRICT AS '$libdir/test_parser', 'testprs_getlexeme'")
      execute("CREATE FUNCTION public.testprs_lextype(internal) RETURNS internal LANGUAGE c STRICT AS '$libdir/test_parser', 'testprs_lextype'")
      execute("CREATE FUNCTION public.testprs_start(internal, integer) RETURNS internal LANGUAGE c STRICT AS '$libdir/test_parser', 'testprs_start'")
      execute("CREATE TEXT SEARCH PARSER public.testparser (START = public.testprs_start, GETTOKEN = public.testprs_getlexeme, END = public.testprs_end, HEADLINE = prsd_headline, LEXTYPES = public.testprs_lextype)")
      execute("CREATE TEXT SEARCH CONFIGURATION public.danbooru (PARSER = public.testparser)")
      execute("ALTER TEXT SEARCH CONFIGURATION public.danbooru ADD MAPPING FOR word WITH simple")
    end

    add_column(:posts, :tag_index, :tsvector)
    add_index(:posts, :tag_index, using: :gin)
    execute("CREATE TRIGGER trigger_posts_on_tag_index_update BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('tag_index', 'public.danbooru', 'tag_string', 'fav_string', 'pool_string')") if testparser_exists
    warn("[RemoveTestparser:down] test_parser does not exist, migration was only partially reverted") unless testparser_exists
  end
end
