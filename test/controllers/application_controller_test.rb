require "test_helper"

class ApplicationControllerTest < ActionController::TestCase
  class CurrentUserController < ApplicationController
    def show
      render json: { user_id: current_user&.id }
    end
  end

  tests CurrentUserController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "show" => "application_controller_test/current_user#show" }
  end

  test "pre-HCA unversioned session is rejected after the cutover" do
    user = User.create!(timezone: "UTC")
    session[:user_id] = user.id

    get :show

    assert_nil response.parsed_body["user_id"]
    assert_nil session[:user_id]
  end

  test "authentication version mismatch rejects the user and clears the session" do
    user = User.create!(timezone: "UTC", authentication_version: 1)
    session[:user_id] = user.id
    session[:authentication_version] = 0

    get :show

    assert_nil response.parsed_body["user_id"]
    assert_nil session[:user_id]
  end

  test "anonymized user is rejected and the session is cleared" do
    user = User.create!(timezone: "UTC", anonymized_at: Time.current, authentication_version: 1)
    session[:user_id] = user.id
    session[:authentication_version] = 1

    get :show

    assert_nil response.parsed_body["user_id"]
    assert_nil session[:user_id]
  end
end
