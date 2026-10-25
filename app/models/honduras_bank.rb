# The banks the account form offers (db/data/honduras_banks.yml), plus
# "other", typed by hand. Each known bank's card has its own colors.
module HondurasBank
  OTHER = "other".freeze
  # Card looks for other banks, picked by the account so each keeps its own.
  OTHER_STYLES = %w[graphite emerald violet teal].freeze

  def self.all
    @all ||= YAML.load_file(Rails.root.join("db/data/honduras_banks.yml")).transform_values { |bank| bank.fetch("name") }.freeze
  end

  def self.keys = all.keys
  def self.choices = keys + [ OTHER ]
  def self.name_of(key) = all[key]
end
