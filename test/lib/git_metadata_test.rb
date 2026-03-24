require "test_helper"
require "open3"
require "tmpdir"

class GitMetadataTest < ActiveSupport::TestCase
  test "uses source commit when git metadata is unavailable" do
    Dir.mktmpdir do |dir|
      metadata = GitMetadata.build(env: { "SOURCE_COMMIT" => "abcdef1234567890" }, root: dir)

      assert_equal "abcdef12", metadata[:version]
      assert_equal 0, metadata[:commit_count]
      assert_equal "https://github.com/hackclub/hackatime/commit/abcdef1234567890", metadata[:commit_link]
    end
  end

  test "returns unknown when no git metadata is available" do
    Dir.mktmpdir do |dir|
      metadata = GitMetadata.build(env: {}, root: dir)

      assert_equal "unknown", metadata[:version]
      assert_equal 0, metadata[:commit_count]
      assert_nil metadata[:commit_link]
    end
  end

  test "builds metadata from a git repository and marks dirty checkouts" do
    Dir.mktmpdir do |dir|
      run_git(dir, "init", "-q")
      run_git(dir, "config", "user.name", "Test User")
      run_git(dir, "config", "user.email", "test@example.com")

      File.write(File.join(dir, "README.md"), "hello\n")
      run_git(dir, "add", "README.md")
      run_git(dir, "commit", "-qm", "Initial commit")

      clean_metadata = GitMetadata.build(env: {}, root: dir)
      commit_hash = run_git(dir, "rev-parse", "HEAD")

      assert_equal commit_hash.slice(0, 8), clean_metadata[:version]
      assert_equal 1, clean_metadata[:commit_count]
      assert_equal "https://github.com/hackclub/hackatime/commit/#{commit_hash}", clean_metadata[:commit_link]

      File.write(File.join(dir, "README.md"), "hello again\n")

      dirty_metadata = GitMetadata.build(env: {}, root: dir)

      assert_equal "#{commit_hash.slice(0, 8)}-dirty", dirty_metadata[:version]
    end
  end

  private

  def run_git(dir, *args)
    output, error, status = Open3.capture3("git", *args, chdir: dir)
    assert status.success?, "git #{args.join(' ')} failed:\n#{output}#{error}"

    output.strip
  end
end
