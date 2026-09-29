# How-to guide shown by the "?" button (HelpGuidesHelper). The text lives in
# es.yml under help_guides:
#
#   help_guides.screens.<controller path>.<action>   one per screen
#   help_guides.processes.<name>                     a flow across screens
#
# Each guide has a title, a summary, steps and optional tips. A screen
# without its own guide gets help_guides.general, so the button always
# shows something; a spec checks that every page has its own.
class HelpGuide
  # Actions that render the same screen as another one: a form shown again
  # with errors is still the form.
  SCREEN_ALIASES = {
    "new" => "form", "create" => "form", "edit" => "form", "update" => "form",
    "reset_password" => "edit_password"
  }.freeze

  GENERAL_KEY = "help_guides.general".freeze

  attr_reader :key

  def self.screen_key(controller_path, action_name)
    action = SCREEN_ALIASES.fetch(action_name.to_s, action_name.to_s)
    "help_guides.screens.#{controller_path.tr("/", ".")}.#{action}"
  end

  def self.for_screen(controller_path, action_name)
    key = screen_key(controller_path, action_name)
    new(I18n.exists?(key) ? key : GENERAL_KEY)
  end

  def self.process(name)
    new("help_guides.processes.#{name}")
  end

  def initialize(key)
    @key = key
    @content = I18n.t(key, raise: true)
  end

  def title = @content.fetch(:title)
  def summary = @content.fetch(:summary)
  def steps = Array(@content.fetch(:steps))
  def tips = Array(@content[:tips])

  # Unique per guide, for the ids the dialog needs.
  def dom_id = "help-guide-#{key.parameterize}"
end
