# frozen_string_literal: true

require("test_helper")

class DTextTest < ActiveSupport::TestCase
  def inspect(filename)
    apng = ApngInspector.new(file_fixture("apng/#{filename}"))
    apng.inspect!
    apng
  end
  context("APNG inspector") do
    should("correctly parse normal APNG file") do
      apng = inspect("normal_apng.png")

      assert_equal(3, apng.frames)
      assert_predicate(apng, :animated?)
      assert_not(apng.corrupted?)
    end

    should("recognize 1-frame APNG as animated") do
      apng = inspect("single_frame.png")

      assert_equal(1, apng.frames)
      assert_predicate(apng, :animated?)
      assert_not(apng.corrupted?)
    end

    should("correctly parse normal PNG file") do
      apng = inspect("not_apng.png")

      assert_not(apng.animated?)
      assert_not(apng.corrupted?)
    end

    should("handle empty file") do
      apng = inspect("empty.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
    end

    should("handle corrupted files") do
      apng = inspect("iend_missing.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
      apng = inspect("misaligned_chunks.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
      apng = inspect("broken.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
    end

    should("handle incorrect acTL chunk") do
      apng = inspect("actl_wronglen.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
      apng = inspect("actl_zero_frames.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
    end

    should("handle non-png files") do
      apng = inspect("jpg.png")

      assert_not(apng.animated?)
      assert_predicate(apng, :corrupted?)
    end
  end
end
