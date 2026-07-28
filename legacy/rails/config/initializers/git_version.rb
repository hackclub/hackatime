# Get the first 6 characters of the current git commit hash
git_hash = ENV["SOURCE_COMMIT"] || `git rev-parse HEAD` rescue "unknown"

commit_link = git_hash != "unknown" ? "https://github.com/hackclub/hackatime/commit/#{git_hash}" : nil

short_hash = git_hash[0..7]

commit_count = `git rev-list --count HEAD`.strip rescue 0

# Check if there are any uncommitted changes
is_dirty = `git status --porcelain`.strip.length > 0 rescue false

# Append "-dirty" if there are uncommitted changes
version = is_dirty ? "#{short_hash}-dirty" : short_hash

# Store server start time
Rails.application.config.server_start_time = Time.current

# Store the version
Rails.application.config.git_version = version
Rails.application.config.git_commit_count = commit_count
Rails.application.config.commit_link = commit_link
