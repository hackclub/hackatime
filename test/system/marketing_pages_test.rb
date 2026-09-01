require "application_system_test_case"

class MarketingPagesTest < ApplicationSystemTestCase
  test "marketing pages preserve their header variants without changing sign in" do
    visit root_path

    within "header" do
      assert_selector "img[alt='Hackatime']"
      assert_link "Philosophy", href: "#philosophy"
      assert_link "Integrations", href: "#integrations"
      assert_link "Sign in", href: %r{/signin\z}
      assert_selector "a[target='_blank']", text: "GitHub"
    end

    visit "/wakatime-alternative"

    within "header" do
      assert_selector "img[alt='Hackatime']"
      assert_link "Philosophy", href: "/#philosophy"
      assert_no_link "Integrations"
      assert_link "Start tracking", href: %r{/signin\z}
      click_link "Start tracking"
    end

    assert_current_path signin_path
    assert_no_selector "header"
    assert_selector "img[alt='Hackatime']"
  end
end
