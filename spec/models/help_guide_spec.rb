require "rails_helper"

RSpec.describe HelpGuide do
  it "reads a screen guide from es.yml" do
    guide = described_class.for_screen("trading/purchases", "index")

    expect(guide.title).to eq("Compras")
    expect(guide.steps).not_to be_empty
  end

  it "shows the form guide while creating, editing or fixing errors" do
    %w[new create edit update].each do |action|
      expect(described_class.for_screen("trading/zones", action).key).to eq("help_guides.screens.trading.zones.form")
    end
  end

  it "falls back to the general guide for a screen without one" do
    expect(described_class.for_screen("errors", "show").key).to eq(HelpGuide::GENERAL_KEY)
  end

  it "reads process guides" do
    expect(described_class.process(:purchase_lifecycle).title).to eq("Etapas de una compra")
  end

  it "has a title, summary and steps in every guide" do
    guides = I18n.t("help_guides.screens").then do |screens|
      collect = ->(node, path) { node.key?(:title) ? [ path ] : node.flat_map { |k, v| collect.(v, "#{path}.#{k}") } }
      collect.(screens, "help_guides.screens")
    end
    guides += I18n.t("help_guides.processes").keys.map { |name| "help_guides.processes.#{name}" }

    (guides + [ HelpGuide::GENERAL_KEY ]).each do |key|
      guide = described_class.new(key)
      expect([ guide.title, guide.summary ]).to all(be_present), key
      expect(guide.steps).to be_present, key
    end
  end
end
