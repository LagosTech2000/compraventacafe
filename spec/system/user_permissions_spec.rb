require "rails_helper"

# Permissions per submodule (Fernando, 2026-11-12): the module's row marks or
# clears an action in all its tabs (permission_matrix_controller.js) and
# shows when only some have it.
RSpec.describe "User permissions", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user, name: "Luis Mejía") }

  def flag(submodule, action)
    row = all("tbody[data-permission-module='trading'] tr").find { it.text.include?(submodule) }
    row.find("input[type=checkbox][data-permission-action='#{action}']")
  end

  def whole_module(action) = find("tbody[data-permission-module='trading'] input[data-permission-matrix-target='all'][data-permission-action='#{action}']")

  it "marks a whole module from its row, says when only some tabs have it, and saves per tab" do
    sign_in_as(admin)
    visit edit_administration_user_path(user)

    whole_module("read").check
    AppModule.submodules("trading").each do |key|
      expect(flag(AppModule.human_submodule("trading", key), "read")).to be_checked
    end

    flag("Zonas", "read").uncheck
    expect(whole_module("read")).not_to be_checked
    expect(page.evaluate_script("document.querySelector(\"tbody[data-permission-module='trading'] input[data-permission-matrix-target='all'][data-permission-action='read']\").indeterminate")).to be(true)

    flag("Facturas", "create").check
    click_button "Guardar cambios"
    expect(page).to have_css(".toast", text: "Usuario actualizado.")

    user.reload
    expect(user.can?("trading.purchases", :read)).to be(true)
    expect(user.can?("trading.zones", :read)).to be(false)
    expect(user.can?("trading.invoices", :create)).to be(true)
    expect(user.can?("trading.purchases", :create)).to be(false)
  end

  # «Copiar permisos de otro usuario» (Fernando, 2026-11-18).
  it "copies another user's permissions into the table, and saves them" do
    create(:user, name: "Ana Zelaya").tap do |model|
      create(:permission, user: model, module_key: "trading", submodule_key: "purchases", can_read: true, can_create: true)
      create(:permission, user: model, module_key: "sales", submodule_key: "stock", can_read: true)
    end
    create(:permission, user:, module_key: "loans", submodule_key: "loans", can_read: true)
    sign_in_as(admin)
    visit edit_administration_user_path(user)

    select "Ana Zelaya", from: "copy_permissions_from"
    expect(flag("Compras", "create")).to be_checked
    expect(page.evaluate_script("document.querySelector(\"tbody[data-permission-module='trading'] input[data-permission-matrix-target='all'][data-permission-action='read']\").indeterminate")).to be(true)
    click_button "Guardar cambios"
    expect(page).to have_css(".toast", text: "Usuario actualizado.")

    user.reload
    expect(user.can?("trading.purchases", :create)).to be(true)
    expect(user.can?("sales.stock", :read)).to be(true)
    expect(user.can?("loans.loans", :read)).to be(false)
  end
end
