require "rails_helper"

RSpec.describe "Data backup" do
  it "lets an admin download it, and audits each download" do
    admin = create(:user, :admin)
    sign_in admin

    get administration_backup_path
    expect(response.body).to include("Respaldo de datos", "Descargar respaldo", "El respaldo incluirá base.dump")

    post administration_backup_path
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to match(/attachment; filename="respaldo-\d{4}-\d{2}-\d{2}-\d{4}\.zip"/)
    event = AuditEvent.where(action: "backup").sole
    expect(event).to have_attributes(user: admin, auditable_label: a_string_starting_with("respaldo-"))
  end

  it "is for admins only" do
    user = create(:user)
    create(:permission, user:, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true)
    sign_in user

    post administration_backup_path
    expect(response).to redirect_to(root_path)
    expect(AuditEvent.where(action: "backup")).to be_empty
  end
end
