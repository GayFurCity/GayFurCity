# frozen_string_literal: true

require("test_helper")

class BulkUpdateRequestCommandsTest < ActiveSupport::TestCase
  include(ActiveJob::TestHelper)

  def assert_command(bur, kind, args = [])
    assert_commands(bur, [kind], [args])
  end

  def assert_commands(bur, kinds, args = [[]] * kinds.size)
    commands = bur.processor.commands

    assert_equal(kinds.size, commands.size, "more commands than expected: #{commands.map(&:command).join(', ')}")
    kinds.each_with_index do |kind, index|
      command = commands.at(index)
      kargs = args.at(index)

      assert_kind_of(kind, commands.at(index))
      kind.arguments.each_with_index do |arg, argindex|
        assert_equal(kargs.at(argindex), command.send(arg))
      end
    end
  end

  def approve!(bur, approver, status: true)
    assert_enqueued_jobs(1, only: ProcessBulkUpdateRequestJob) do
      bur.approve!(approver)
    end
    assert_equal("queued", bur.reload.status)
    perform_enqueued_jobs(only: ProcessBulkUpdateRequestJob)
    assert_equal("approved", bur.reload.status) if status
  end

  def assert_errors(user, script, content)
    ApplicationRecord.transaction do
      yield if block_given?
      bur = build(:bulk_update_request, script: script, skip_forum: true, title: random, creator: user)
      bur.save!(validate: false)

      assert_equal(content.is_a?(Proc) ? content.call : content, bur.processor.script_errors.map(&:full_messages).flatten.uniq.join("; "))
      raise(ActiveRecord::Rollback)
    end
  end

  def assert_comments(user, script, content)
    ApplicationRecord.transaction do
      yield if block_given?
      bur = build(:bulk_update_request, script: script, skip_forum: true, title: random, creator: user)
      bur.save!(validate: false)

      assert_equal(content.is_a?(Proc) ? content.call : content, bur.processor.script_comments.map(&:full_messages).flatten.uniq.join("; "))
      raise(ActiveRecord::Rollback)
    end
  end

  context("Bulk update request commands") do
    setup do
      @user = create(:user)
      @admin = create(:admin_user)
      @tag, @tag2 = create_list(:tag, 2)
    end

    context("change category") do
      setup do
        @bur = create(:bulk_update_request, script: "category #{@tag.name} -> copyright", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::ChangeCategory, [@tag.name, "copyright", nil])
      end

      should("format") do
        create(:post, tag_string: @tag.name)

        assert_equal("category [[#{@tag.name}]] (1) -> copyright", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal(TagCategory.copyright, @tag.reload.category)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::ChangeCategory.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_errors(@user, "category #{@tag.name} -> none", "invalid category")
        assert_comments(@user, "category missing -> general", "missing")
      end
    end

    context("comment") do
      setup do
        @bur = create(:bulk_update_request, script: "# abc", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Comment, ["abc"])
      end

      should("format") do
        assert_equal("# abc", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::Comment.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("collapse") do
        bur = create(:bulk_update_request, script: "# a\n# b\n# c", skip_forum: true, title: random)

        assert_equal("# a\n# b; c", bur.script)
      end

      should("limit") do
        stub_const(BulkUpdateRequestCommands, :MAX_EMPTY_LINES, Float::INFINITY) do
          bur = create(:bulk_update_request, script: "# a\n\n# b\n\n# c\n\n# d\n\n# b\n\n# e\n\n# f\n\n# g\n\n# h\n\n# i\n\n# j", skip_forum: true, title: random)

          assert_equal("# a\n\n# b\n\n# c\n\n# d\n\n# b\n\n# e\n\n# f\n\n# g\n\n# h\n\n# i; j", bur.script)
        end
      end
    end

    context("alias") do
      setup do
        @bur = create(:bulk_update_request, script: "alias #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::CreateAlias, [@tag.name, @tag2.name, nil])
      end

      should("format") do
        create(:post, tag_string: @tag.name)
        create_list(:post, 2, tag_string: @tag2.name)

        assert_equal("alias [[#{@tag.name}]] (1) -> [[#{@tag2.name}]] (2)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_predicate(TagAlias.active.where(antecedent_name: @tag.name, consequent_name: @tag2.name), :exists?)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::CreateAlias.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_comments(@user, "alias missing -> #{@tag2.name}", "antecedent tag is missing")
        assert_comments(@user, "alias #{@tag.name} -> #{@tag2.name}", -> { "duplicate of alias ##{TagAlias.last.id}" }) do
          create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "pending")
        end
        assert_errors(@user, "alias #{@tag.name} -> #{@tag2.name}", "Error: Antecedent name has already been taken") do
          create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "pending")
        end
        assert_comments(@user, "alias #{@tag.name} -> #{@tag2.name}", -> { "duplicate of alias ##{TagAlias.last.id}; has blocking transitive relationships, cannot be applied through BUR" }) do
          create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "pending")
          create(:tag_implication, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        end
        assert_comments(@user, "alias #{@tag.name} -> #{@tag2.name}", "has blocking transitive relationships, cannot be applied through BUR") do
          create(:tag_implication, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        end
      end
    end

    context("imply") do
      setup do
        @bur = create(:bulk_update_request, script: "imply #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::CreateImplication, [@tag.name, @tag2.name, nil])
      end

      should("format") do
        create(:post, tag_string: @tag.name)
        create_list(:post, 2, tag_string: @tag2.name)

        assert_equal("imply [[#{@tag.name}]] (1) -> [[#{@tag2.name}]] (2)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_predicate(TagImplication.active.where(antecedent_name: @tag.name, consequent_name: @tag2.name), :exists?)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::CreateImplication.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_comments(@user, "imply #{@tag.name} -> #{@tag2.name}", -> { "duplicate of implication ##{TagImplication.last.id}" }) do
          create(:tag_implication, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "pending")
        end
        assert_errors(@user, "imply #{@tag.name} -> #{@tag2.name}", "Error: Antecedent tag must not be aliased to another tag") do
          create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        end
      end
    end

    context("deprecate") do
      setup do
        create(:wiki_page, title: @tag.name)
        @bur = create(:bulk_update_request, script: "deprecate #{@tag.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Deprecate, [@tag.name, nil])
      end

      should("format") do
        create(:post, tag_string: @tag.name)

        assert_equal("deprecate [[#{@tag.name}]] (1)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)
        @tag.reload

        assert_equal(TagCategory.invalid, @tag.category)
        assert_predicate(@tag, :is_deprecated?)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::Deprecate.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_comments(@user, "deprecate missing", "missing")
        assert_comments(@user, "deprecate #{@tag2.name}", "must have wiki page")
        assert_comments(@user, "deprecate #{@tag2.name}", "already deprecated") do
          create(:wiki_page, title: @tag2.name)
          @tag2.update_columns(is_deprecated: true)
        end
      end
    end

    context("empty line") do
      setup do
        # leading/trailing empty lines will be stripped
        @bur = create(:bulk_update_request, script: "# abc\n\n# def", skip_forum: true, title: random)
      end

      should("parse") do
        assert_commands(@bur, [BulkUpdateRequestCommands::Comment, BulkUpdateRequestCommands::EmptyLine, BulkUpdateRequestCommands::Comment], [["abc"], [], ["def"]])
      end

      should("format") do
        assert_equal("# abc\n\n# def", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::EmptyLine.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("collapse") do
        bur = create(:bulk_update_request, script: "# a\n\n\n# b", skip_forum: true, title: random)

        assert_equal("# a\n\n# b", bur.script)
      end

      should("limit") do
        stub_const(BulkUpdateRequestCommands, :MAX_COMMENTS, Float::INFINITY) do
          bur = create(:bulk_update_request, script: "# a\n\n# b\n\n# c\n\n# d\n\n# b\n\n# e\n\n# f\n\n# g\n\n# h\n\n# i\n\n# j\n\n# k", skip_forum: true, title: random)

          assert_equal("# a\n\n# b\n\n# c\n\n# d\n\n# b\n\n# e\n\n# f\n\n# g\n\n# h\n\n# i\n\n# j\n# k", bur.script)
        end
      end
    end

    context("mass update") do
      setup do
        @post = create(:post, tag_string: @tag.name.to_s)
        @bur = create(:bulk_update_request, script: "update #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::MassUpdate, [@tag.name, @tag2.name, nil])
      end

      should("format") do
        assert_equal("update {{#{@tag.name}}} (1) -> {{#{@tag2.name}}}", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal("#{@tag.name} #{@tag2.name}", @post.reload.tag_string)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::MassUpdate.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_errors(@user, "update #{(1..41).to_a.join(' ')} -> tag", "antecedent query exceeds the maximum tag count")
        assert_errors(@user, "update score:0 -> tag", "antecedent query is not simple")
        assert_errors(@user, "update tag -> #{(1..41).to_a.join(' ')}", "consequent query exceeds the maximum tag count")
        assert_errors(@user, "update tag -> score:0", "consequent query is not simple")
      end
    end

    context("nuke") do
      setup do
        @post = create(:post, tag_string: "#{@tag.name} #{@tag2.name}")
        @bur = create(:bulk_update_request, script: "nuke #{@tag.name}", skip_forum: true, title: random, creator: @admin)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Nuke, [@tag.name, nil])
      end

      should("format") do
        assert_equal("nuke {{#{@tag.name}}} (1)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal(@tag2.name, @post.reload.tag_string)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::Nuke.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_errors(@user, "nuke tag", "you cannot use this command")
        assert_errors(@admin, "nuke #{(1..41).to_a.join(' ')}", "query exceeds the maximum tag count")
        assert_errors(@admin, "nuke score:0", "query is not simple")
      end
    end

    context("unalias") do
      setup do
        @ta = create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        @bur = create(:bulk_update_request, script: "unalias #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::RemoveAlias, [@tag.name, @tag2.name, "alias ##{@ta.id}"])
      end

      should("format") do
        create(:post, tag_string: @tag.name)
        create_list(:post, 2, tag_string: @tag2.name)

        assert_equal("unalias [[#{@tag.name}]] (0) -> [[#{@tag2.name}]] (3) # alias ##{@ta.id}", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal("deleted", @ta.reload.status)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::RemoveAlias.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        @ta.destroy
        assert_comments(@user, "unalias #{@tag.name} -> #{@tag2.name}", -> { "alias ##{TagAlias.last.id}" }) do
          create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        end
        assert_comments(@user, "unalias #{@tag.name} -> #{@tag2.name}", "missing")
      end
    end

    context("unimply") do
      setup do
        @ti = create(:tag_implication, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        @bur = create(:bulk_update_request, script: "unimply #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::RemoveImplication, [@tag.name, @tag2.name, "implication ##{@ti.id}"])
      end

      should("format") do
        create(:post, tag_string: @tag.name)
        create_list(:post, 2, tag_string: @tag2.name)

        assert_equal("unimply [[#{@tag.name}]] (1) -> [[#{@tag2.name}]] (3) # implication ##{@ti.id}", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal("deleted", @ti.reload.status)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::RemoveImplication.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        @ti.destroy
        assert_comments(@user, "unimply #{@tag.name} -> #{@tag2.name}", -> { "implication ##{TagImplication.last.id}" }) do
          create(:tag_implication, antecedent_name: @tag.name, consequent_name: @tag2.name, status: "active")
        end
        assert_comments(@user, "unimply #{@tag.name} -> #{@tag2.name}", "missing")
      end
    end

    context("rename") do
      setup do
        @tag.update_columns(category: TagCategory.artist)
        @post = create(:post, tag_string: @tag.name)
        @bur = create(:bulk_update_request, script: "rename #{@tag.name} -> #{@tag2.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Rename, [@tag.name, @tag2.name, nil])
      end

      should("format") do
        create_list(:post, 2, tag_string: @tag2.name)

        assert_equal("rename [[#{@tag.name}]] (1) -> [[#{@tag2.name}]] (2)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)

        assert_equal(TagCategory.artist, @tag2.reload.category)
        assert_equal(@tag2.name, @post.reload.tag_string)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::Rename.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        @tag.update_columns(category: TagCategory.general)

        assert_comments(@user, "rename missing -> #{@tag2.name}", "antecedent tag missing")
        assert_errors(@user, "rename #{@tag.name} -> #{@tag2.name}", "antecedent tag is not an artist tag")
        assert_errors(@user, "rename #{@tag.name} -> #{@tag2.name}", "antecedent tag has too many posts") do
          @tag.update_columns(category: TagCategory.artist, post_count: BulkUpdateRequestCommands::Rename::POST_LIMIT + 1)
        end
        assert_errors(@user, "rename #{@tag.name} -> #{@tag2.name}", "consequent tag is not an artist tag") do
          @tag.update_columns(category: TagCategory.artist)
          @tag2.update_columns(post_count: 1)
        end
        assert_errors(@user, "rename #{@tag.name} -> #{@tag2.name}", "antecedent tag has too many posts") do
          @tag.update_columns(category: TagCategory.artist)
          @tag.update_columns(category: TagCategory.artist, post_count: BulkUpdateRequestCommands::Rename::POST_LIMIT + 1)
        end
      end
    end

    context("undeprecate") do
      setup do
        @tag.update_columns(is_deprecated: true, category: TagCategory.invalid)
        @bur = create(:bulk_update_request, script: "undeprecate #{@tag.name}", skip_forum: true, title: random)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Undeprecate, [@tag.name, nil])
      end

      should("format") do
        create(:post, tag_string: @tag.name)

        assert_equal("undeprecate [[#{@tag.name}]] (1)", @bur.processor.dtext)
      end

      should("process") do
        approve!(@bur, @admin)
        @tag.reload

        assert_equal(TagCategory.general, @tag.category)
        assert_not(@tag.is_deprecated?)
      end

      should("fail to process if invalid") do
        BulkUpdateRequestCommands::Undeprecate.any_instance.stubs(:valid?).returns(false)
        approve!(@bur, @admin, status: false)

        assert_equal("error: Cannot approve invalid commands: ", @bur.reload.status)
      end

      should("validate") do
        assert_comments(@user, "undeprecate missing", "missing")
        assert_comments(@user, "undeprecate #{@tag2.name}", "not deprecated")
      end
    end

    context("invalid") do
      setup do
        @bur = build(:bulk_update_request, script: "invalid", skip_forum: true, title: random, creator: @user)
        @bur.save!(validate: false)
      end

      should("parse") do
        assert_command(@bur, BulkUpdateRequestCommands::Invalid, ["invalid"])
      end

      should("format") do
        assert_equal("invalid", @bur.processor.dtext)
      end

      should("fail to process") do
        approve!(@bur, @admin, status: false)

        assert_equal("error: Error: Cannot approve invalid commands", @bur.reload.status)
      end
    end
  end
end
