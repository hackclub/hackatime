module RepoHost
  class RateLimitError < StandardError
    attr_reader :retry_at

    def initialize(message = nil, retry_at: nil)
      super(message)
      @retry_at = retry_at
    end
  end
end
