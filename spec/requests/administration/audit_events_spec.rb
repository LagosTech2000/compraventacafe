require "rails_helper"

RSpec.describe "Administration::AuditEvents" do
  let!(:admin) { create(:user, :admin) }

  it "records sign in, sign out and failed attempts with the IP" do
    sign_in admin
    delete session_path
    post session_path, params: { email_address: "intruso@example.com", password: "x" }
    expect(AuditEvent.pluck(:action, :auditable_label)).to include(
      [ "sign_in", admin.audit_label ], [ "sign_out", admin.audit_label ], [ "sign_in_failed", "intruso@example.com" ]
    )
    expect(AuditEvent.find_by(action: "sign_in").ip_address).to eq("127.0.0.1")
  end

  it "records who changed a user's permissions from the admin panel" do
    sign_in admin
    user = create(:user)
    patch administration_user_path(user), params: {
      user: { permissions_attributes: { "0" => { module_key: "trading", can_read: "1" } } }
    }
    event = AuditEvent.find_by!(auditable_type: "Permission", action: "create")
    expect(event.user).to eq(admin)
    expect(event.auditable_label).to eq("#{user.email_address}: Compra y venta de café")
    expect(event.request_id).to be_present
  end

  it "is only for admins, even with every administration flag" do
    user = create(:user)
    create(:permission, user:, module_key: "administration", can_read: true, can_create: true, can_update: true, can_destroy: true)
    sign_in user
    get administration_audit_events_path
    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in admin }

    it "filters by user, action, entity, text and dates" do
      other = create(:user, email_address: "otra@example.com")
      allow(Current).to receive(:user).and_return(other)
      create(:zone, name: "Pueblo Nuevo")
      allow(Current).to receive(:user).and_call_original

      get administration_audit_events_path(user_id: other.id, event_action: "create", auditable_type: "Zone", q: "pueblo",
                                           from: Time.zone.today.iso8601, to: Time.zone.today.iso8601)
      rows = Nokogiri::HTML(response.body).css("tbody tr")
      expect(rows.size).to eq(1)
      expect(rows.first.text).to include("Pueblo Nuevo", "otra@example.com", "Creó", "Zona")

      get administration_audit_events_path(auditable_type: "Invoice")
      expect(response.body).to include("No hay acciones que coincidan")
    end

    it "shows the record's id and filters a record's whole history by it" do
      allow(Current).to receive(:user).and_return(admin)
      purchase = create(:purchase)
      purchase.update!(price_per_pound: 60)
      create(:purchase)
      allow(Current).to receive(:user).and_call_original

      get administration_audit_event_path(AuditEvent.find_by!(auditable: purchase, action: "update"))
      fields = Nokogiri::HTML(response.body).css("dl > div").to_h { |d| [ d.at_css("dt").text.strip, d.at_css("dd").text.strip ] }
      expect(fields["ID del registro"]).to eq(purchase.id.to_s)

      get administration_audit_events_path(auditable_type: "Purchase", auditable_id: purchase.id)
      rows = Nokogiri::HTML(response.body).css("tbody tr")
      expect(rows.size).to eq(2)
      expect(rows.map(&:text)).to all(include("##{purchase.id}"))
    end

    it "ignores garbage in the filters" do
      get administration_audit_events_path(from: "ayer", event_action: "drop table", auditable_type: "Kernel", page: "-3")
      expect(response).to have_http_status(:ok)
    end

    it "pages through the log" do
      allow(Current).to receive(:user).and_return(admin)
      create_list(:zone, AuditEventFilter::PER_PAGE + 1)
      allow(Current).to receive(:user).and_call_original
      get administration_audit_events_path(auditable_type: "Zone")
      expect(response.body).to include("Siguiente")
      get administration_audit_events_path(auditable_type: "Zone", page: 2)
      expect(Nokogiri::HTML(response.body).css("tbody tr").size).to eq(1)
    end

    it "shows a change field by field, in Spanish" do
      allow(Current).to receive(:user).and_return(admin)
      user = create(:user)
      user.update!(active: false, password: "nueva-clave-segura")
      allow(Current).to receive(:user).and_call_original

      get administration_audit_event_path(AuditEvent.find_by!(auditable_type: "User", action: "update"))
      page = Nokogiri::HTML(response.body)
      cells = page.css("tbody tr").map { |row| row.css("td").map { |td| td.text.strip } }
      expect(cells).to include([ "Activo", "Sí", "No" ], [ "Contraseña", "(oculto)", "(oculto)" ])
    end

    it "ends with a JSON-like diff: previous value in red, new one in emerald" do
      allow(Current).to receive(:user).and_return(admin)
      purchase = create(:purchase)
      purchase.update!(price_per_pound: 60)
      allow(Current).to receive(:user).and_call_original

      get administration_audit_event_path(AuditEvent.find_by!(auditable: purchase, action: "update"))
      line = Nokogiri::HTML(response.body).at_css("#json-diff [data-field='price_per_pound']")
      expect(line.text).to include('"Precio por libra (L)"', " → ")
      expect(line.at_css("del.text-diff-removed").text).to end_with('"58.0"')
      expect(line.at_css("ins.text-diff-added").text).to end_with('"60.0"')
    end

    it "shows only new values for a creation and only previous ones for a deletion" do
      allow(Current).to receive(:user).and_return(admin)
      zone = create(:zone, name: "El Chilito")
      zone.destroy!
      allow(Current).to receive(:user).and_call_original

      get administration_audit_event_path(AuditEvent.find_by!(auditable_type: "Zone", action: "create"))
      diff = Nokogiri::HTML(response.body).at_css("#json-diff")
      expect(diff.css("del")).to be_empty
      expect(diff.at_css("ins").text).to include('"El Chilito"')

      get administration_audit_event_path(AuditEvent.find_by!(auditable_type: "Zone", action: "destroy"))
      diff = Nokogiri::HTML(response.body).at_css("#json-diff")
      expect(diff.css("ins")).to be_empty
    end

    it "translates closed lists in the detail" do
      allow(Current).to receive(:user).and_return(admin)
      purchase = create(:purchase, coffee_state: "cherry")
      allow(Current).to receive(:user).and_call_original
      get administration_audit_event_path(AuditEvent.find_by!(auditable: purchase, action: "create"))
      expect(response.body).to include("Uva")
    end
  end
end
