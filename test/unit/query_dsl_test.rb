# frozen_string_literal: true

require("test_helper")

Rails.application.eager_load! # needed to get all classes
MODELS = ApplicationRecord.subclasses.reject(&:abstract_class)
class QueryDslTest < ActiveSupport::TestCase
  context("#query_dsl") do
    MODELS.each do |klass|
      should("validate for #{klass.name}") do
        assert_nothing_raised { klass.query_dsl }
      end
    end
  end

  context("#apply_order") do
    MODELS.each do |klass|
      should("validate for #{klass.name}") do
        assert_nothing_raised { klass.apply_order({}) }
      end
    end
  end

  context("#search") do
    setup do
      @user = create(:owner_user)
    end

    MODELS.each do |klass|
      should("validate for #{klass.name}") do
        assert_nothing_raised { klass.search({}, @user) }
      end
    end
  end
end
