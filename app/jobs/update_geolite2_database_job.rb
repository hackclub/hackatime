require "fileutils"
require "tmpdir"
require "net/http"

class UpdateGeolite2DatabaseJob < ApplicationJob
  queue_as :literally_whenever

  DB_FILE = Rails.root.join("db/geo/GeoLite2-City.mmdb")
  DOWNLOAD_URL = URI("https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz")
  MAX_REDIRECTS = 5

  def perform
    return log_skip("MAXMIND credentials not set") unless credentials_present?

    remote_mtime = head_last_modified
    return log_skip("could not determine remote Last-Modified") unless remote_mtime
    return log_skip("database up to date") if up_to_date?(remote_mtime)

    install_fresh_database(remote_mtime)
  rescue => e
    report_error(e, message: "GeoLite2 database update failed")
    raise
  end

  private

  def credentials_present?
    ENV["MAXMIND_ACCOUNT_ID"].present? && ENV["MAXMIND_LICENSE_KEY"].present?
  end

  def up_to_date?(remote_mtime)
    DB_FILE.exist? && remote_mtime <= DB_FILE.mtime
  end

  def install_fresh_database(remote_mtime)
    FileUtils.mkdir_p(DB_FILE.dirname)

    Dir.mktmpdir("geolite2_update", DB_FILE.dirname) do |dir|
      tar_path = File.join(dir, "geolite2.tar.gz")
      download_archive(tar_path)

      system("tar", "-xzf", tar_path, "-C", dir, exception: true)

      mmdb = Dir.glob(File.join(dir, "GeoLite2-City_*/GeoLite2-City.mmdb")).first
      raise "GeoLite2-City.mmdb not found in archive" unless mmdb

      replacement = DB_FILE.dirname.join(".GeoLite2-City.mmdb.tmp")
      FileUtils.cp(mmdb, replacement)
      FileUtils.mv(replacement, DB_FILE.to_s)
      Rails.logger.info "GeoLite2 updated (built #{remote_mtime}) at #{DB_FILE}"
    end
  end

  def head_last_modified
    response = request(Net::HTTP::Head, DOWNLOAD_URL)
    Time.httpdate(response["Last-Modified"]) if response.is_a?(Net::HTTPSuccess) && response["Last-Modified"]
  rescue ArgumentError
    nil
  end

  def download_archive(path)
    File.open(path, "wb") do |file|
      request(Net::HTTP::Get, DOWNLOAD_URL) do |response|
        ensure_success!(response)
        response.read_body { |chunk| file.write(chunk) }
      end
    end
  end

  def request(klass, url, redirects: MAX_REDIRECTS, &block)
    req = klass.new(url)
    req.basic_auth(ENV["MAXMIND_ACCOUNT_ID"], ENV["MAXMIND_LICENSE_KEY"]) if url.host == DOWNLOAD_URL.host

    Net::HTTP.start(url.host, url.port, use_ssl: true, read_timeout: 300, open_timeout: 30) do |http|
      http.request(req) do |response|
        if response.is_a?(Net::HTTPRedirection) && redirects.positive?
          return request(klass, URI.join(url, response["location"]), redirects: redirects - 1, &block)
        end
        ensure_success!(response) unless block_given?
        block&.call(response)
        return response
      end
    end
  end

  def ensure_success!(response)
    return if response.is_a?(Net::HTTPSuccess)
    raise "MaxMind auth failed — check credentials" if response.is_a?(Net::HTTPUnauthorized)
    raise "MaxMind request failed: #{response.code} #{response.message}"
  end

  def log_skip(reason)
    Rails.logger.info "UpdateGeolite2DatabaseJob: skipping — #{reason}"
  end
end
