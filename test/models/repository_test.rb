require "test_helper"

class RepositoryTest < ActiveSupport::TestCase
  test "parse_url extracts host owner and name" do
    parsed = Repository.parse_url("https://github.com/hackclub/hackatime")

    assert_equal "github.com", parsed[:host]
    assert_equal "hackclub", parsed[:owner]
    assert_equal "hackatime", parsed[:name]
  end

  test "formatted_languages truncates to top three with ellipsis" do
    repository = Repository.new(languages: "Ruby, JavaScript, TypeScript, Go")

    assert_equal "Ruby, JavaScript, TypeScript...", repository.formatted_languages
  end
end
