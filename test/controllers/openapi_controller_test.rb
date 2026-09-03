require "test_helper"

class OpenapiControllerTest < ActionDispatch::IntegrationTest
  test "serves the OpenAPI document as JSON" do
    get openapi_path

    assert_response :success
    assert_equal "application/json", response.media_type

    document = JSON.parse(response.body)
    assert_equal "3.0.1", document["openapi"]
    assert_equal "Hackatime API", document.dig("info", "title")
    assert document["paths"].present?, "expected the document to describe at least one path"
    assert_includes document["paths"].keys, "/api/hackatime/v1/users/{id}/heartbeats"
  end

  test "serves the OpenAPI document as YAML" do
    get openapi_yaml_path

    assert_response :success
    assert_equal "application/yaml", response.media_type
    assert_equal YAML.safe_load(Rails.root.join("swagger", "v1", "swagger.yaml").read, aliases: true),
      YAML.safe_load(response.body, aliases: true)
  end

  test "JSON and YAML representations describe the same document" do
    get openapi_path
    json_document = JSON.parse(response.body)

    get openapi_yaml_path
    yaml_document = YAML.safe_load(response.body, aliases: true)

    assert_equal yaml_document, json_document
  end

  test "serves the document from the /api aliases too" do
    get api_openapi_path
    assert_response :success
    assert_equal "application/json", response.media_type

    get api_openapi_yaml_path
    assert_response :success
    assert_equal "application/yaml", response.media_type
  end

  test "document is publicly cacheable and readable cross-origin" do
    get openapi_path

    assert_response :success
    assert_match(/public/, response.headers["Cache-Control"])
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "document is served without authentication" do
    get openapi_path

    assert_response :success
    assert_nil session[:user_id]
  end

  test "pages advertise the OpenAPI document with a service-desc link" do
    get root_path

    assert_response :success
    assert_includes response.body, %(<link rel="service-desc" type="application/json" href="/openapi.json">)
  end

  test "robots.txt lets crawlers reach the OpenAPI document" do
    robots = Rails.root.join("public", "robots.txt").read

    assert_includes robots, "Allow: /openapi.json"
    assert_includes robots, "Allow: /openapi.yaml"
    assert_includes robots, "Allow: /api/openapi.json"
    assert_includes robots, "Allow: /api/openapi.yaml"
  end

  test "document declares the production server" do
    get openapi_path

    servers = JSON.parse(response.body)["servers"]
    assert_includes servers.map { |server| server.dig("variables", "defaultHost", "default") },
      "hackatime.hackclub.com"
  end
end
