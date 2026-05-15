# XXX Testing modules should not have a say in if we can or cannot use assert_equal with nil
# https://github.com/minitest/minitest/issues/666
# TODO: look into refactoring out minitest?
module Minitest
  module Assertions
    def assert_equal(exp, act, msg = nil)
      assert(exp == act, message(msg, E) { diff(exp, act) }) # rubocop:disable Minitest/AssertOperator, Minitest/AssertEqual, Minitest/AssertWithExpectedArgument
    end
  end
end

# line number should be where the assert above is
Rails.backtrace_cleaner.add_silencer { |line| line =~ /test\/test_helpers\/minitest\.rb:7/ }
