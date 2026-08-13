revision_path = Rails.root.join("REVISION") # this used to be SOURCE_COMMIT, but Coolify overrides it as HEAD
source_commit = if revision_path.file?
  revision_path.read.strip.presence
else
  ENV["SOURCE_COMMIT"].presence
end

if source_commit
  git_hash = source_commit
  is_dirty = false
else
  git_hash = `git rev-parse HEAD 2>/dev/null`.strip.presence || "unknown"
  is_dirty = `git status --porcelain 2>/dev/null`.present?
end

commit_link = git_hash != "unknown" ? "https://github.com/hackclub/hackatime/commit/#{git_hash}" : nil
short_hash = git_hash[0..7]
version = is_dirty ? "#{short_hash}-dirty" : short_hash

Rails.application.config.server_start_time = Time.current
Rails.application.config.git_version = version
Rails.application.config.commit_link = commit_link
