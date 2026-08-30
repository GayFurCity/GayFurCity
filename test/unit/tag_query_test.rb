# frozen_string_literal: true

require("test_helper")

class TagQueryTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  should("scan a query") do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan("~AAa -BBB* -bbb*"))
    assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan('aaa test:"with spaces" def'))
  end

  should("not strip out valid characters when scanning") do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
  end

  should("parse a query") do
    create(:tag, name: "acb")

    assert_equal(["abc"], TagQuery.new("md5:abc", @user)[:md5])
    assert_equal([[:between, 1, 2]], TagQuery.new("id:1..2", @user)[:post_id])
    assert_equal([[:gt, 2]], TagQuery.new("id:>2", @user)[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("id:<3", @user)[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("ID:<3", @user)[:post_id])
    assert_equal(["acb"], TagQuery.new("a*b", @user)[:tags][:should])
  end

  should("allow multiple types for a metatag in a single query") do
    query = TagQuery.new("id:1 -id:2 ~id:3 id:4 -id:5 ~id:6", @user)

    assert_equal([[:eq, 1], [:eq, 4]], query[:post_id])
    assert_equal([[:eq, 2], [:eq, 5]], query[:post_id_must_not])
    assert_equal([[:eq, 3], [:eq, 6]], query[:post_id_should])
  end

  should("fail for more than 40 tags") do
    assert_raise(TagQuery::CountExceededError) do
      TagQuery.new("rating:s width:10 height:10 user:bob #{[*'aa'..'zz'].join(' ')}", @user)
    end
  end

  context("anonymous_hard_tag_limit") do
    should("reject an anonymous query over the limit before parsing it") do
      AdminConfig.any_instance.stubs(:anonymous_hard_tag_limit).returns(2)
      TagQuery.any_instance.expects(:parse_query).never

      assert_raise(TagQuery::CountExceededError) do
        TagQuery.new("a b c", User.anonymous)
      end
    end

    should("not affect logged-in users") do
      AdminConfig.any_instance.stubs(:anonymous_hard_tag_limit).returns(2)

      assert_nothing_raised do
        TagQuery.new("a b c", @user)
      end
    end

    should("not reject an anonymous query at or under the limit") do
      AdminConfig.any_instance.stubs(:anonymous_hard_tag_limit).returns(2)

      assert_nothing_raised do
        TagQuery.new("a b", User.anonymous)
      end
    end
  end

  context("{} character group syntax") do
    should("keep a {} block as one token when scanning") do
      assert_equal(["{a b c}"], TagQuery.scan("{a b c}"))
      assert_equal(["-{a b c}"], TagQuery.scan("-{a b c}"))
    end

    should("parse {a b c} into a must tag_groups entry") do
      query = TagQuery.new("{fluffy_(oc) blue_eyes}", @user)

      assert_equal([%w[fluffy_(oc) blue_eyes]], query[:tag_groups][:must])
      assert_equal([], query[:tag_groups][:must_not])
    end

    should("parse -{a b c} into a must_not tag_groups entry") do
      query = TagQuery.new("-{fluffy_(oc) blue_eyes}", @user)

      assert_equal([%w[fluffy_(oc) blue_eyes]], query[:tag_groups][:must_not])
      assert_equal([], query[:tag_groups][:must])
    end

    should("leave bare tags in the query untouched by a {} group") do
      query = TagQuery.new("solo {fluffy_(oc) blue_eyes} duo", @user)

      assert_equal(%w[solo duo], query[:tags][:must])
      assert_equal([%w[fluffy_(oc) blue_eyes]], query[:tag_groups][:must])
    end

    should("support multiple {} groups in one query") do
      query = TagQuery.new("{a b} {c d}", @user)

      assert_equal([%w[a b], %w[c d]], query[:tag_groups][:must])
    end

    should("resolve aliases within a {} group") do
      create(:tag_alias, antecedent_name: "old_name", consequent_name: "new_name")
      query = TagQuery.new("{fluffy_(oc) old_name}", @user)

      assert_equal([%w[fluffy_(oc) new_name]], query[:tag_groups][:must])
    end

    should("count each tag inside a {} group toward the tag query limit") do
      assert_raise(TagQuery::CountExceededError) do
        TagQuery.new("{#{[*'aa'..'zz'].join(' ')}}", @user)
      end
    end
  end
end
