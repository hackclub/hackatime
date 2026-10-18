class Cachet
  class ApiError < StandardError; end

  def self.user(slack_uid)
    response = HTTP.timeout(10)
      .get("https://cachet.hackclub.com/users/#{ERB::Util.url_encode(slack_uid)}")

    # Cache misses return placeholder data while Cachet fetches the profile.
    return nil if response.status.code == 202
    raise ApiError, "Cachet user API request failed: HTTP #{response.status.code}" unless response.status.code == 200

    JSON.parse(response.body.to_s)
  end
end
