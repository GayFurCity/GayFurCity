# frozen_string_literal: true

require("test_helper")

class BulkUpdateRequestProcessorTest < ActiveSupport::TestCase
  context("The bulk update request processor") do
    setup do
      @user = create(:admin_user)
    end

    context("#estimate_update_count") do
      resets_post_index!

      setup do
        create(:post, tag_string: "aaa")
        create(:post, tag_string: "bbb")
        create(:post, tag_string: "ccc")
        create(:post, tag_string: "ddd")
        create(:post, tag_string: "eee")

        @script = "alias aaa -> 000\n" \
                  "imply bbb -> 111\n" \
                  "unalias ccc -> 222\n" \
                  "unimply ddd -> 333\n" \
                  "update eee -> 444"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("return the correct count") do
        assert_equal(3, @processor.estimate_update_count)
      end
    end

    context("#tags") do
      setup do
        @script = "alias aaa -> 000\n" \
                  "imply bbb -> 111"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("return the correct tags") do
        assert_equal(%w[aaa 000 bbb 111], @processor.tags)
      end
    end

    context("#category_changes") do
      setup do
        create(:tag, name: "aaa")
        @script = "category aaa -> artist\n" \
                  "category bbb -> general"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("return the correct value") do
        assert_equal([[Tag.find_by!(name: "aaa"), TagCategory.artist]], @processor.category_changes)
      end
    end

    context("#dtext") do
      resets_post_index!

      setup do
        create(:post, tag_string: "aaa")
        create(:post, tag_string: "bbb")
        create(:post, tag_string: "bbb ccc")
        @script = "alias aaa -> bbb\n" \
                  "imply bbb -> ccc"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("return the correct value") do
        dtext = "alias [[aaa]] (1) -> [[bbb]] (2)\n" \
                "imply [[bbb]] (2) -> [[ccc]] (1)"

        assert_equal(dtext, @processor.dtext)
      end
    end

    context("with a valid script") do
      setup do
        @script = "alias aaa -> bbb\n" \
                  "imply bbb -> ccc"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("process correctly") do
        @processor.process!(@user)

        assert(TagAlias.active.exists?(antecedent_name: "aaa", consequent_name: "bbb"))
        assert(TagImplication.active.exists?(antecedent_name: "bbb", consequent_name: "ccc"))
      end
    end

    context("with an invalid script") do
      setup do
        @script = "invalid a -> b"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("fail") do
        assert_raises(BulkUpdateRequestCommands::ProcessingError) { @processor.process!(@user) }
      end
    end

    context("script length") do
      setup do
        stub_config_get_user(:bur_entry_limit, 1)
        @script = "alias aaa -> bbb\n" \
                  "imply bbb -> ccc"

        @processor = BulkUpdateRequestProcessor.new(@script, nil, creator: @user)
      end

      should("be validated") do
        assert_not(@processor.valid?)
        assert_equal(["Script cannot have more than 1 entries"], @processor.errors.full_messages)
      end
    end
  end
end
