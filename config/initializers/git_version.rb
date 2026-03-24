require Rails.root.join("lib/git_metadata")

metadata = GitMetadata.build

# Store server start time
Rails.application.config.server_start_time = Time.current

# Store the version
Rails.application.config.git_version = metadata[:version]
Rails.application.config.git_commit_count = metadata[:commit_count]
Rails.application.config.commit_link = metadata[:commit_link]
