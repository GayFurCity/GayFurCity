# frozen_string_literal: true

require("test_helper")

module PostSearch
  class FieldsTest < ActiveSupport::TestCase
    context("PostSearch::Fields") do
      should("expose at least one category") do
        assert_predicate(Fields.categories, :any?)
      end

      should("list every field under one of the declared categories") do
        assert(Fields.fields.all? { |f| Fields.categories.include?(f.category) })
      end

      should("find a field by its metatag name") do
        field = Fields.find(:rating)

        assert_not_nil(field)
        assert_equal(:select, field.type)
        assert_equal(:rating, field.metatag)
      end

      should("return nil for an unregistered metatag") do
        assert_nil(Fields.find(:not_a_real_metatag))
      end

      should("only list fields for the requested category via fields_for") do
        category = Fields.fields.first.category

        assert(Fields.fields_for(category).all? { |f| f.category == category })
        assert_predicate(Fields.fields_for(category), :any?)
      end

      should("expose range-capable numeric metatags as :range fields") do
        %i[width height mpixels ratio filesize duration framecount score favcount views tagcount comment_count change id disapprovals].each do |metatag|
          field = Fields.find(metatag)

          assert_not_nil(field, "expected a field for #{metatag}")
          assert_equal(:range, field.type, "expected #{metatag} to be a :range field")
        end
      end

      should("expose one range field per tag category for its tag count metatag") do
        assert_equal(:range, Fields.find(:chartags).type)
        assert_equal(:range, Fields.find(:spectags).type)
      end

      should("leave date-domain metatags as plain text, since they use a different grammar than ParseValue.range") do
        assert_equal(:text, Fields.find(:date).type)
        assert_equal(:text, Fields.find(:age).type)
      end

      should("mark comparison-negatable metatags as negatable and non-comparison ones as not") do
        assert(Fields.find(:score).negatable)
        assert_not(Fields.find(:order).negatable)
      end
    end
  end
end
