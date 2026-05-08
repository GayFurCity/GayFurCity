# frozen_string_literal: true

require("test_helper")

class ChangeSeqTest < ActiveSupport::TestCase
  def new_value(column, type, current)
    case column
    when :rating
      (%w[s q e] - [current]).sample
    when :qtags
      %W[#{SecureRandom.hex(4)}]
    when :bg_color
      SecureRandom.hex(3)
    when :source
      "https://example.com/#{SecureRandom.hex(4)}"
    when :approver_id
      create(:janitor_user).id
    when :parent_id
      create(:post).id
    when :bit_flags
      if current.allbits?(1)
        current & ~1
      else
        current | 1
      end
    when :tag_string, :locked_tags
      [*current.split, SecureRandom.hex(4)].sort.join(" ")
    when :typed_tag_string
      [*current.split, "0|#{SecureRandom.hex(4)}"].sort.join(" ")
    else
      case type
      when :integer
        current.to_i + 1
      when :boolean
        !current
      when :datetime
        rand(1..100).minutes.from_now.round(6).utc
      when :text
        SecureRandom.hex(4)
      end
    end
  end

  context("The posts_trigger_change_seq function") do
    should("Check or ignore all columns in the posts table") do
      missed = Post.get_change_seq_missed
      missed.each do |column|
        TraceLogger.error("ValidateChangeSeq", "Column #{column} not checked or ignored in function")
      end

      assert_empty(missed, "The posts_trigger_change_seq function does not check or ignore: #{missed.join(', ')}")
    end

    context("change_seq") do
      setup do
        # columns which would be reset by callbacks
        @force_columns = %i[comment_count tag_count_general tag_count_artist tag_count_contributor tag_count_character tag_count_copyright tag_count_meta tag_count_species tag_count_invalid tag_count_lore tag_count_gender tag_count_important typed_tag_string]
        @post = create(:webm_post)
      end

      Post.get_change_seq_tracked.each do |column|
        should("update when the #{column} column changes") do
          type = Post.columns_hash[column.to_s].type
          old_value = @post.send(column)
          old_seq = @post.change_seq
          set_value = new_value(column, type, old_value)
          if @force_columns.include?(column)
            @post.update_column(column, set_value)
          else
            @post.update!(column => set_value)
          end
          @post.reload
          new_value = @post.send(column)
          new_seq = @post.change_seq

          assert_not_equal(old_value, new_value, "The #{column} (#{type}) column did not change (#{old_value} -> #{set_value})")
          assert_equal(set_value, new_value, "The #{column} (#{type}) column did not update to the new value")
          assert_not_equal(old_seq, new_seq, "The change_seq did not change when the #{column} (#{type}) column changed (#{old_value} -> #{new_value})")
        end
      end
    end
  end
end
