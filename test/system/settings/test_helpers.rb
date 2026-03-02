module SettingsSystemTestHelpers
  private

  def assert_settings_page(path:, marker_text:)
    visit path

    assert_current_path path, ignore_query: true
    assert_text "Settings"
    assert_text marker_text
  end

  def choose_select_option(select_id, option_text)
    find("##{select_id}").click
    assert_selector ".dashboard-select-popover"

    within ".dashboard-select-popover" do
      find("[role='option']", text: option_text, match: :first).click
    end
  end

  def within_modal(&)
    within ".bits-modal-content", &
  end
end
