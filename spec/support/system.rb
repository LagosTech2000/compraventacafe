require "capybara/cuprite"

# System specs run each screen in a headless Chrome, so the JavaScript
# (Stimulus controllers) is tested as the user sees it. Chrome must be
# installed: locally `google-chrome` in WSL, in CI the one GitHub Actions
# ships. BROWSER_PATH points to another Chrome when needed.
# Ferrum waits this long for Chrome to start (its default, 10 s, is too
# short for a cold start on the CI runner).
ENV["FERRUM_PROCESS_TIMEOUT"] ||= "30"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1440, 1000 ], headless: true, process_timeout: 20,
                                     browser_options: { "no-sandbox" => nil })
end

Capybara.default_max_wait_time = 5
# Icon buttons are named by aria-label (the × of a toast): find them by it.
Capybara.enable_aria_label = true
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite
  end
end

module SystemHelpers
  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: AuthenticationHelpers::PASSWORD
    find("[type=submit]").click
    expect(page).to have_no_current_path(new_session_path)
  end

  # The drawer slides in: click once it is in place (clicks go by position).
  def wait_for_drawer
    drawer = find("dialog.drawer[open]")
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("getComputedStyle(document.querySelector('dialog.drawer[open]')).transform") == "none"
    end
    drawer
  end
end

RSpec.configure { |config| config.include SystemHelpers, type: :system }
