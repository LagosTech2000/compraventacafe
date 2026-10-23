require "capybara/cuprite"

# System specs run each screen in a headless Chrome, so the JavaScript
# (Stimulus controllers) is tested as the user sees it. Chrome must be
# installed: locally `google-chrome` in WSL, in CI the one GitHub Actions
# ships. BROWSER_PATH points to another Chrome when needed.
#
# The options go through driven_by: Rails registers its own :cuprite driver
# there, so a Capybara.register_driver(:cuprite) of ours would be replaced
# and never used. process_timeout: how long Ferrum waits for Chrome to start
# (its default, 10 s, is too short for a cold start on the CI runner). The
# window is the size the specs were written for (Rails' default).
CUPRITE_OPTIONS = { process_timeout: 60, browser_options: { "no-sandbox" => nil } }.freeze

Capybara.default_max_wait_time = 5
# Icon buttons are named by aria-label (the × of a toast): find them by it.
Capybara.enable_aria_label = true
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [ 1400, 1400 ], options: CUPRITE_OPTIONS.dup
  end

  # At the end of each screen spec, before its data is rolled back: leave
  # the page (its timers stop: a search typed a moment ago, a live refresh)
  # and wait for the requests already sent, so none reaches the server
  # during the next spec. A form left with changes (unsaved_changes_controller.js)
  # would stop it with its "leave the page?" question: forgotten first. A
  # failed spec keeps its page for the screenshot.
  config.after(:each, type: :system) do |example|
    next if example.exception

    page.execute_script("document.querySelectorAll('[data-dirty]').forEach((form) => delete form.dataset.dirty)")
    Capybara.reset_sessions!
    # Its Action Cable connections close too (presence leaves) before the next spec.
    executor = ActionCable.server.worker_pool.executor
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
    until (ActionCable.server.connections.empty? && executor.queue_length.zero? && executor.active_count.zero?) ||
          Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.02
    end
  rescue StandardError
    nil
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

  # A searchable picker (record_picker_controller.js): typing a record's whole
  # label chooses it once the search answers; the box is valid then.
  def pick_record(field, label)
    fill_in field, with: label
    expect(page).to have_css("##{field}:valid")
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
