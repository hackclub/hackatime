require "open3"

module GitMetadata
  module_function

  def build(env: ENV, root: Rails.root)
    git_hash = env["SOURCE_COMMIT"].presence || git_output(root, "rev-parse", "HEAD")
    short_hash = git_hash&.slice(0, 8)
    commit_count = git_output(root, "rev-list", "--count", "HEAD")&.to_i || 0
    dirty = git_output(root, "status", "--porcelain").present?

    {
      commit_count: commit_count,
      commit_link: git_hash.present? ? "https://github.com/hackclub/hackatime/commit/#{git_hash}" : nil,
      version: short_hash.present? ? "#{short_hash}#{'-dirty' if dirty}" : "unknown"
    }
  end

  def git_output(root, *args)
    stdout, _stderr, status = Open3.capture3("git", *args, chdir: root.to_s)
    return unless status.success?

    stdout.strip.presence
  rescue Errno::ENOENT
    nil
  end
end
