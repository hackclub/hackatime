module RepoHost
  # A temporary GitHub failure (5xx). Callers retry later and must not record
  # it as a completed sync.
  class ServerError < StandardError; end
end
