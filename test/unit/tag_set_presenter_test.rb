# frozen_string_literal: true

require("test_helper")

class TagSetPresenterTest < ActiveSupport::TestCase
  context("TagSetPresenter") do
    setup do
      create(:tag, name: "bkub", category: TagCategory.artist)
      create(:tag, name: "chen", category: TagCategory.character)
      create(:tag, name: "cirno", category: TagCategory.character)
      create(:tag, name: "solo", category: TagCategory.general)
      create(:tag, name: "touhou", category: TagCategory.copyright)
    end

    context("#split_tag_list_text method") do
      should("list all categories in order") do
        text = TagSetPresenter.new(%w[bkub chen cirno solo touhou]).split_tag_list_text

        assert_equal("bkub \ntouhou \nchen cirno \nsolo", text)
      end

      should("skip empty categories") do
        text = TagSetPresenter.new(%w[bkub solo]).split_tag_list_text

        assert_equal("bkub \nsolo", text)
      end
    end
  end
end
