require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Compraventacafe
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    # Show unexpected errors as a Spanish alert instead of an error page.
    # Off by default so development shows the full trace; on in production.
    config.x.friendly_errors = false

    # Map tiles for the location of people and farms (OpenStreetMap: free, no
    # key; its usage policy asks for the attribution the map shows). Specs
    # set it to nil: they never reach the internet.
    config.x.map_tiles_url = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

    # Errors that never reach a controller's ErrorHandling (an unknown
    # address, a failure in a middleware) are audited (ErrorAudit) and then
    # answered with the same Spanish static pages of public/.
    config.exceptions_app = lambda do |env|
      ErrorAudit.from_env(env)
      ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
    end

    config.time_zone = "America/Tegucigalpa"
    config.i18n.available_locales = [ :es ]
    config.i18n.default_locale = :es

    config.generators.system_tests = nil
  end
end
