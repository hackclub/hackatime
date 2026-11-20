class HeartbeatImportDumpClient
  class ResponseError < StandardError
    attr_reader :status
    def initialize(message = nil, status: nil)
      @status = status
      super(message)
    end
  end

  class AuthenticationError < ResponseError; end
  class TransientError < ResponseError; end
  class RequestError < ResponseError; end
  class ManualDownloadLinkRequiredError < RequestError; end
  class ExistingDumpError < RequestError; end

  BASE_URLS = {
    "wakatime_dump" => "https://wakatime.com/api/v1",
    "wakatime_download_link" => "https://wakatime.com/api/v1",
    "hackatime_v1_dump" => "https://waka.hackclub.com/api/v1"
  }.freeze
  WAKATIME_DOWNLOAD_HOST = "wakatime.s3.amazonaws.com".freeze
  WAKATIME_OAUTH_URL = "https://wakatime.com/oauth".freeze
  WAKATIME_OAUTH_SCOPES = "read_heartbeats,read_stats.editors,read_stats.machines".freeze
  TIMEOUTS = { connect: 5, read: 60, write: 15 }.freeze
  DOWNLOAD_ACCEPT = "application/json,application/octet-stream,*/*".freeze

  def initialize(source_kind:, api_key:)
    @source_kind = source_kind.to_s
    @endpoint_url = BASE_URLS.fetch(@source_kind)
    @api_key = api_key.to_s
  end

  def request_dump
    body = request_json(method: :post, path: "/users/current/data_dumps",
                        json: { type: "heartbeats", email_when_finished: false })
    normalize_dump(body.fetch("data"))
  rescue ExistingDumpError
    existing_dump!
  end

  def list_dumps
    Array(request_json(method: :get, path: "/users/current/data_dumps")["data"]).map { normalize_dump(_1) }
  end

  def download_dump(download_url)
    response = HTTP.follow.timeout(TIMEOUTS).headers(download_headers(download_url)).get(download_url)
    handle_response_errors(response)
    response.to_s
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  end

  def list_user_agents
    request_all_pages("/users/current/user_agents").map { normalize_user_agent(_1) }
  end

  def list_machine_names
    request_all_pages("/users/current/machine_names").map { { id: _1["id"].to_s, value: _1["value"].presence } }
  end

  # One day in the user's WakaTime timezone.
  def list_heartbeats(date)
    Array(request_json(method: :get, path: "/users/current/heartbeats?date=#{date.iso8601}")["data"])
  end

  def self.wakatime_authorize_url(redirect_uri:, state:)
    query = { client_id: ENV.fetch("WAKATIME_CLIENT_ID"), response_type: "code", redirect_uri:, scope: WAKATIME_OAUTH_SCOPES, state: }
    "#{WAKATIME_OAUTH_URL}/authorize?#{query.to_query}"
  end

  def self.exchange_wakatime_code(code:, redirect_uri:)
    response = HTTP.timeout(TIMEOUTS).headers(accept: "application/json").post("#{WAKATIME_OAUTH_URL}/token", form: {
      client_id: ENV.fetch("WAKATIME_CLIENT_ID"), client_secret: ENV.fetch("WAKATIME_CLIENT_SECRET"),
      redirect_uri:, grant_type: "authorization_code", code:
    })
    token = JSON.parse(response.to_s)["access_token"] if response.status.success?
    raise AuthenticationError.new("WakaTime did not return an access token (#{response.status.to_i})", status: response.status.to_i) if token.blank?
    token
  rescue JSON::ParserError
    raise AuthenticationError.new("WakaTime returned an invalid token response", status: response.status.to_i)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  end

  # Import tokens are single-use; WakaTime keeps at most 8 per app and user.
  def self.revoke_wakatime_token(token)
    return if ENV["WAKATIME_CLIENT_ID"].blank? || ENV["WAKATIME_CLIENT_SECRET"].blank?

    response = HTTP.timeout(TIMEOUTS).post("#{WAKATIME_OAUTH_URL}/revoke", form: {
      client_id: ENV["WAKATIME_CLIENT_ID"], client_secret: ENV["WAKATIME_CLIENT_SECRET"], token:
    })
    status = response.status.to_i
    raise TransientError.new("WakaTime token revocation failed (#{status})", status:) if status == 408 || status == 429 || status >= 500
    raise RequestError.new("WakaTime token revocation failed (#{status})", status:) unless response.status.success?
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  end

  def self.valid_wakatime_download_url?(download_url)
    uri = URI.parse(download_url.to_s)
    uri.scheme == "https" && uri.host == WAKATIME_DOWNLOAD_HOST && uri.path.present?
  rescue URI::InvalidURIError
    false
  end

  private

  def request_json(method:, path:, json: nil)
    request = HTTP.timeout(TIMEOUTS).headers(headers)
    url = "#{@endpoint_url}#{path}"
    response = json.nil? ? request.public_send(method, url) : request.public_send(method, url, json:)
    handle_response_errors(response, method:, path:)
    JSON.parse(response.to_s)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    raise TransientError, e.message
  rescue JSON::ParserError
    raise RequestError, "Invalid JSON response"
  end

  def request_all_pages(path)
    (1..).each_with_object([]) do |page, items|
      body = request_json(method: :get, path: "#{path}?page=#{page}")
      items.concat(Array(body["data"]))
      break items if page >= body["total_pages"].to_i
    end
  end

  def handle_response_errors(response, method: nil, path: nil)
    status = response.status.to_i
    raise AuthenticationError.new("Authentication failed (#{status})", status:) if [ 401, 403 ].include?(status)
    raise TransientError.new("Request failed with status #{status}", status:) if status == 408 || status == 429 || status >= 500
    raise ExistingDumpError.new("An export already exists.", status:) if existing_dump?(response, status:, method:, path:)
    raise ManualDownloadLinkRequiredError.new("WakaTime requires a recent export download link.", status:) if manual_download_link_required?(status:, method:, path:)
    raise RequestError.new("Request failed with status #{status}", status:) unless response.status.success?
  end

  def manual_download_link_required?(status:, method:, path:)
    status == 400 && @source_kind == "wakatime_dump" && method == :post && path == "/users/current/data_dumps"
  end

  def existing_dump?(response, status:, method:, path:)
    return false unless status == 400 && method == :post && path == "/users/current/data_dumps"

    body = response.to_s
    case @source_kind
    when "hackatime_v1_dump" then body.include?("a data export is already in progress")
    # "...to finish" or "...to expire"; either way that export can be reused.
    when "wakatime_dump" then body.include?("Wait for your current export to")
    else false
    end
  end

  def existing_dump!
    dumps = list_dumps.select { |item| item[:type] == "heartbeats" && !item[:has_failed] }
      .sort_by { |item| item[:created_at].to_s }.reverse
    dump = dumps.find { |item| item[:is_processing] } || dumps.find { |item| item[:download_url].present? }
    return dump if dump.present?
    raise ManualDownloadLinkRequiredError.new("WakaTime requires a recent export download link.", status: 400) if @source_kind == "wakatime_dump"
    raise RequestError.new("The provider reported an active data export, but none could be found.", status: 400)
  end

  def normalize_dump(dump)
    payload = dump.respond_to?(:with_indifferent_access) ? dump.with_indifferent_access : dump.to_h.with_indifferent_access
    bool = ActiveModel::Type::Boolean.new
    {
      id: payload[:id].to_s,
      status: payload[:status].to_s,
      percent_complete: payload[:percent_complete].to_f,
      download_url: payload[:download_url].presence,
      type: payload[:type].to_s,
      is_processing: bool.cast(payload[:is_processing]),
      is_stuck: bool.cast(payload[:is_stuck]),
      has_failed: bool.cast(payload[:has_failed]),
      expires: payload[:expires],
      created_at: payload[:created_at]
    }
  end

  def normalize_user_agent(user_agent)
    payload = user_agent.respond_to?(:with_indifferent_access) ? user_agent.with_indifferent_access : user_agent.to_h.with_indifferent_access
    {
      id: payload[:id].to_s,
      value: payload[:value].to_s,
      editor: payload[:editor].presence,
      os: payload[:os].presence
    }
  end

  def headers
    { "Authorization" => "Basic #{Base64.strict_encode64(basic_auth_credential)}",
      "Accept" => "application/json", "Content-Type" => "application/json" }
  end

  def download_headers(download_url)
    uri = URI.parse(download_url)
    if uri.host == URI.parse(@endpoint_url).host
      headers.merge("Accept" => DOWNLOAD_ACCEPT)
    else
      { "Accept" => DOWNLOAD_ACCEPT }
    end
  rescue URI::InvalidURIError
    { "Accept" => DOWNLOAD_ACCEPT }
  end

  def basic_auth_credential
    @source_kind == "wakatime_dump" ? "#{@api_key}:" : @api_key
  end
end
