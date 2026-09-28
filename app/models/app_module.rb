# Canonical list of application modules and the actions a permission can grant.
# Adding a module = a key here + its name in config/locales/es.yml + its
# controller namespace.
class AppModule
  KEYS = %w[administration trading farms loans reports].freeze
  ACTIONS = %w[read create update destroy].freeze

  def self.human_name(key)
    I18n.t("app_modules.#{key}")
  end

  def self.human_action(action)
    I18n.t("app_modules.actions.#{action}")
  end
end
