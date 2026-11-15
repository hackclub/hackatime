module HCAService
  def host
    if Rails.env.production?
      "https://auth.hackclub.com"
    else
      "https://hca.dinosaurbbq.org"
    end
  end

  def me(user_token)
    raise ArgumentError, "user_token is required" unless user_token

    response = HTTP.use(:raise_error)
                   .auth("Bearer " + user_token)
                   .get(host + "/api/v1/me")
    JSON.parse(response.body)
  end
  module_function :me, :host
end
