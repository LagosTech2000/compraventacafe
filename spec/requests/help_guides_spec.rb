require "rails_helper"

RSpec.describe "Help guides" do
  let(:admin) { create(:user, :admin) }

  def help_buttons
    Nokogiri::HTML(response.body).css("[data-controller='help-guide']")
  end

  it "has its own guide for every page of the app" do
    pages = Rails.application.routes.routes.filter_map do |route|
      controller, action = route.defaults.values_at(:controller, :action)
      next unless route.verb == "GET" && controller && !controller.start_with?("rails/", "turbo/")

      [ controller, action ]
    end

    missing = pages.uniq.reject { |controller, action| I18n.exists?(HelpGuide.screen_key(controller, action)) }
    expect(missing).to be_empty, "pages without a guide in es.yml (help_guides.screens): #{missing.map { |c, a| "#{c}##{a}" }.join(", ")}"
  end

  it "puts a help button in the navigation with the guide of the page" do
    sign_in admin
    get trading_purchases_path

    button = Nokogiri::HTML(response.body).at_css("header nav [data-controller='help-guide']")
    expect(button.at_css("button")["aria-label"]).to eq("Ayuda: Compras")
    expect(button.at_css("template").inner_html).to include("Lista de compras")
  end

  it "has one help dialog, apart from the modal" do
    sign_in admin
    get root_path

    page = Nokogiri::HTML(response.body)
    expect(page.css("dialog#help-guide[data-controller='help-dialog']").size).to eq(1)
    expect(page.at_css("dialog[data-controller='modal'] #help-guide")).to be_nil
  end

  it "puts the guide of the page opened in the modal next to its close button" do
    sign_in admin
    get new_trading_zone_path, headers: { "Turbo-Frame" => "modal" }

    expect(help_buttons.size).to eq(1)
    expect(help_buttons.first.at_css("button")["aria-label"]).to eq("Ayuda: Crear o editar una zona")
  end

  it "helps on the sign-in page too" do
    get new_session_path

    expect(help_buttons.first.at_css("button")["aria-label"]).to eq("Ayuda: Iniciar sesión")
  end

  it "explains the purchase lifecycle where its steps are shown" do
    sign_in admin
    get trading_purchase_path(create(:purchase))

    expect(help_buttons.map { |b| b.at_css("button")["aria-label"] }).to include("Ayuda: Etapas de una compra")
  end
end
