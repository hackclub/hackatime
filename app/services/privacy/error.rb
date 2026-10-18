module Privacy
  class Error < StandardError
    attr_reader :status

    def initialize(code, status)
      @status = status
      super(code)
    end
  end
end
