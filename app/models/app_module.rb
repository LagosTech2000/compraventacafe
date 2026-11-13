# Canonical list of application modules, their submodules and the actions a
# permission can grant. Adding a module = a key here + its submodules + their
# names in config/locales/es.yml + its controller namespace. Their order is
# how every menu, the home page tiles and the permission screens list them:
# Administración last (Fernando, 2026-10-13).
#
# Permissions are granted per submodule (Fernando, 2026-11-12): one per tab
# of the module's bar. A module is open to whoever reads any of its
# submodules. Users, audit, site settings, private documents, merging people
# and the backup stay for administrators and are not submodules.
#
# A permission key is "module" (any of its submodules) or
# "module.submodule" (that one).
class AppModule
  SUBMODULES = {
    "trading" => %w[purchases invoices daily_close producers haulers zones],
    "sales" => %w[shipments sales stock coffee_conversions daily_close buyers carriers vehicles supplies],
    "farms" => %w[payrolls farms expense_categories],
    "loans" => %w[loans credit_accounts coffee_collection collection_calendar portfolio seasons daily_close simulation],
    "finance" => %w[movements incomes expenses investments accounts consolidation budget staff categories],
    "reports" => %w[reports],
    "administration" => %w[people farms zones]
  }.transform_values(&:freeze).freeze
  KEYS = SUBMODULES.keys.freeze
  ACTIONS = %w[read create update destroy].freeze

  # Every "module.submodule" key, in the order of the screens.
  PERMISSION_KEYS = SUBMODULES.flat_map { |key, subs| subs.map { "#{key}.#{it}" } }.freeze

  def self.submodules(key) = SUBMODULES.fetch(key.to_s)

  # "trading.invoices" => ["trading", "invoices"]; "trading" => ["trading", nil].
  # Raises on anything that is not a module or one of its submodules.
  def self.split(permission_key)
    module_key, submodule_key = permission_key.to_s.split(".", 2)
    raise ArgumentError, "unknown module: #{module_key}" unless SUBMODULES.key?(module_key)
    raise ArgumentError, "unknown submodule: #{permission_key}" if submodule_key && !SUBMODULES[module_key].include?(submodule_key)

    [ module_key, submodule_key ]
  end

  # A module with a single submodule shows as the module alone.
  def self.single?(key) = submodules(key).one?

  def self.human_name(key)
    I18n.t("app_modules.#{key}")
  end

  def self.human_submodule(key, submodule_key)
    I18n.t("app_modules.submodules.#{key}.#{submodule_key}")
  end

  def self.human_action(action)
    I18n.t("app_modules.actions.#{action}")
  end
end
