# frozen_string_literal: true

require("test_helper")

class GitHelperTest < ActiveSupport::TestCase
  def build_helper
    GitHelper.send(:new)
  end

  context("GitHelper") do
    context("with a git repository present (non-production)") do
      should("populate origin from git and leave upstream unset") do
        helper = build_helper

        assert_predicate(helper, :enabled?)
        assert(helper.git_exists)
        assert_predicate(helper, :repo_exists?)
        assert_instance_of(GitHelper::Ref, helper.origin)
        assert_equal(`git rev-parse #{helper.origin.remote}/#{helper.origin.branch}`.strip, helper.origin.commit)
        assert_nil(helper.upstream)
        assert_same(helper.origin, helper.public_ref)
        assert_equal(helper.origin.commit[0..7], helper.public_ref.short_commit)
      end
    end

    context("with only a REVISION file (no .git, e.g. a built production image)") do
      should("fall back to the revision file for origin and use a commitless upstream marker") do
        commit = "9fd76b75cd45f478aae0edf98e69ac2c894ebad0"
        GitHelper.stubs(:revision_file_commit).returns(commit)
        GitHelper.any_instance.stubs(:system).returns(false)

        helper = build_helper

        assert_predicate(helper, :enabled?)
        assert_instance_of(GitHelper::RevisionRef, helper.origin)
        assert_equal(commit, helper.origin.commit)
        assert_instance_of(GitHelper::RevisionRef, helper.upstream)
        assert_nil(helper.upstream.commit)

        # The regression this covers: with an unresolved upstream commit, the footer
        # must still show a short hash for the deployed commit, not fall through to
        # rendering the bare commit URL as the link text.
        assert_same(helper.origin, helper.public_ref)
        assert_equal(commit[0..7], helper.public_ref.short_commit)
      end
    end

    context("with neither git nor a REVISION file") do
      should("stay disabled") do
        GitHelper.stubs(:revision_file_commit).returns(nil)
        GitHelper.any_instance.stubs(:system).returns(false)

        helper = build_helper

        assert_not(helper.enabled?)
        assert_nil(helper.origin)
        assert_nil(helper.upstream)
      end
    end
  end

  context("#public_ref") do
    should("prefer upstream when its commit is resolved") do
      helper = GitHelper.send(:allocate)
      origin = GitHelper::RevisionRef.new("origincommit12345678", "https://example.com/origin")
      upstream = GitHelper::RevisionRef.new("upstreamcommit12345678", "https://example.com/upstream", branch: "master")
      helper.instance_variable_set(:@origin, origin)
      helper.instance_variable_set(:@upstream, upstream)

      assert_same(upstream, helper.public_ref)
    end

    should("fall back to origin when upstream's commit could not be resolved") do
      helper = GitHelper.send(:allocate)
      origin = GitHelper::RevisionRef.new("origincommit12345678", "https://example.com/origin")
      upstream = GitHelper::RevisionRef.new(nil, "https://example.com/upstream", branch: "master")
      helper.instance_variable_set(:@origin, origin)
      helper.instance_variable_set(:@upstream, upstream)

      assert_same(origin, helper.public_ref)
      assert_equal(origin.short_commit, helper.public_ref.short_commit)
    end

    should("fall back to origin when there is no upstream at all") do
      helper = GitHelper.send(:allocate)
      origin = GitHelper::RevisionRef.new("origincommit12345678", "https://example.com/origin")
      helper.instance_variable_set(:@origin, origin)
      helper.instance_variable_set(:@upstream, nil)

      assert_same(origin, helper.public_ref)
    end
  end

  context("#public_commit_url") do
    should("link to a real commit sha even when upstream's commit is unresolved") do
      helper = GitHelper.send(:allocate)
      commit = "9fd76b75cd45f478aae0edf98e69ac2c894ebad0"
      origin = GitHelper::RevisionRef.new(commit, "https://github.com/GayFurCity/GayFurCity")
      upstream = GitHelper::RevisionRef.new(nil, "https://github.com/GayFurCity/GayFurCity", branch: "master")
      helper.instance_variable_set(:@origin, origin)
      helper.instance_variable_set(:@upstream, upstream)

      GitHelper::RemoteComparison.any_instance.stubs(:common).returns(commit)

      assert_equal("https://github.com/GayFurCity/GayFurCity/commit/#{commit}", helper.public_commit_url)
      assert_equal(commit[0..7], helper.public_ref.short_commit)
    end
  end
end
