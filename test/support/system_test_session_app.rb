# frozen_string_literal: true

class SystemTestSessionApp
  def call(env)
    request = Rack::Request.new(env)
    user = User.find_by(id: request.path_info.delete_prefix("/").to_i)
    return [ 404, { "content-type" => "text/plain" }, [ "Unknown user" ] ] unless user

    request.session[:user_id] = user.id
    request.session.delete(:impersonater_user_id)
    [ 200, { "content-type" => "text/plain" }, [ "Signed in" ] ]
  end
end
