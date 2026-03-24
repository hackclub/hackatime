module WakatimeShared
  extend ActiveSupport::Concern

  class_methods do
    def parse_user_agent(user_agent)
      # Based on https://github.com/muety/wakapi/blob/b3668085c01dc0724d8330f4d51efd5b5aecaeb2/utils/http.go#L89
      user_agent_pattern = /wakatime\/[^ ]+ \(([^)]+)\)(?: [^ ]+ ([^\/]+)(?:\/([^\/]+))?)?/

      if matches = user_agent.match(user_agent_pattern)
        os = matches[1].split("-").first
        editor = matches[2] || ""
        { os: os, editor: editor, err: nil }
      elsif browser_ua = user_agent.match(/^([^\/]+)\/([^\/\s]+)/)
        if user_agent.include?("wakatime")
          full_os = user_agent.split(" ")[1]
          if full_os.present?
            os = full_os.include?("_") ? full_os.split("_")[0] : full_os
            { os: os, editor: browser_ua[1].downcase, err: nil }
          else
            { os: "", editor: "", err: "failed to parse user agent string" }
          end
        else
          { os: browser_ua[1], editor: browser_ua[2], err: nil }
        end
      else
        { os: "", editor: "", err: "failed to parse user agent string" }
      end
    rescue => e
      { os: "", editor: "", err: "failed to parse user agent string" }
    end
  end

  private

  def convert_to_unix_timestamp(timestamp)
    return nil if timestamp.nil?

    case timestamp
    when String
      Time.parse(timestamp).to_i
    when Time, DateTime, Date
      timestamp.to_i
    when Numeric
      timestamp.to_i
    end
  rescue ArgumentError
    nil
  end
end
