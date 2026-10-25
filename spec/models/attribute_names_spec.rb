require "rails_helper"

# Every field of the business's records has its name in Spanish: forms,
# error messages and the audit log show it (a missing one shows the English
# column, as «Buyer» did in Comercialización, Fernando 2026-10-25).
RSpec.describe "Attribute names" do
  it "names every column of the audited models in es.yml" do
    missing = AuditEvent::AUDITED_TYPES.flat_map do |type|
      model = type.constantize
      (model.column_names - %w[id created_at updated_at lock_version])
        .reject { |column| I18n.exists?("activerecord.attributes.#{model.model_name.i18n_key}.#{column}") }
        .map { |column| "#{type}.#{column}" }
    end
    expect(missing).to be_empty, "untranslated: #{missing.join(", ")}"
  end
end
