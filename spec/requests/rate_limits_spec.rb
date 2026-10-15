require "rails_helper"

RSpec.describe "Rate limits" do
  let(:admin) { create(:user, :admin) }

  describe "in front of the app (rack-attack)" do
    it "answers 429 in Spanish past the requests per IP, and audits it once" do
      stub_const("Rack::Attack::REQUEST_LIMIT", 3)
      with_rack_attack do
        3.times { get new_session_path }
        expect(response).to have_http_status(:ok)

        2.times { get new_session_path }
        expect(response).to have_http_status(:too_many_requests)
        expect(response.body).to include("Demasiadas solicitudes", "Espera unos minutos")
        expect(response.headers["retry-after"]).to eq(5.minutes.to_i.to_s)
      end

      event = AuditEvent.where(action: "rate_limited").sole
      expect(event).to have_attributes(user: nil, ip_address: "127.0.0.1", auditable_label: "requests_per_ip GET /session/new")
      expect(event.details).to include("rule" => "requests_per_ip", "path" => "/session/new")
    end

    it "does not count assets or the health check" do
      stub_const("Rack::Attack::REQUEST_LIMIT", 1)
      with_rack_attack do
        3.times { get "/up" }
        expect(response).to have_http_status(:ok)
        get new_session_path
        expect(response).to have_http_status(:ok)
      end
    end

    it "bans for an hour an IP that probes for attack addresses" do
      with_rack_attack do
        get "/wp-login.php"
        expect(response).to have_http_status(:too_many_requests)
        get "/.env"
        get new_session_path
        expect(response).to have_http_status(:ok)

        get "/phpmyadmin/index.php"
        get new_session_path
        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["retry-after"]).to eq(1.hour.to_i.to_s)
      end

      expect(AuditEvent.where(action: "rate_limited").pluck(:auditable_label)).to eq([ "scanner_ban GET /wp-login.php" ])
    end

    it "keeps serving icons and the health check to a banned IP" do
      with_rack_attack do
        %w[/wp-login.php /.env /phpmyadmin/index.php].each { |path| get path }
        get new_session_path
        expect(response).to have_http_status(:too_many_requests)

        %w[/favicon.ico /icon.svg /icon.png /apple-touch-icon.png /up].each do |path|
          get path
          expect(response).to have_http_status(:ok), path
        end
      end
    end

    it "lets the app's own addresses through" do
      with_rack_attack do
        sign_in admin
        5.times { get trading_purchases_path(q: "php env git") }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "per user on expensive screens" do
    before { sign_in make_data_exporter(admin) }

    it "allows three backups an hour" do
      allow_any_instance_of(DataBackup).to receive(:write) do
        Dir.mktmpdir.then { |dir| File.join(dir, "respaldo.zip").tap { |path| File.write(path, "zip") } }
      end

      3.times { post administration_backup_path }
      expect(response.media_type).to eq("application/zip")

      post administration_backup_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Hiciste esto demasiadas veces en poco tiempo. Espera unos minutos y vuelve a intentarlo.")
      event = AuditEvent.where(action: "rate_limited").sole
      expect(event).to have_attributes(user: admin, auditable_label: "backup POST /administration/backup")
      expect(AuditEvent.where(action: "backup").count).to eq(3)
    end

    it "allows ten CSV exports a minute, without limiting the report itself" do
      10.times { get reports_report_path("purchases", format: :csv) }
      expect(response.media_type).to eq("text/csv")

      get reports_report_path("purchases", format: :csv), headers: { "HTTP_REFERER" => reports_report_url("purchases") }
      expect(response).to redirect_to(reports_report_url("purchases"))
      expect(flash[:alert]).to include("demasiadas veces")

      get reports_report_path("purchases")
      expect(response).to have_http_status(:ok)
    end

    it "answers the charts frame with the alert inside it" do
      60.times { get reports_report_charts_path("purchases") }
      expect(response).to have_http_status(:ok)

      get reports_report_charts_path("purchases"), headers: { "Turbo-Frame" => "report-charts" }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('<turbo-frame id="report-charts">', "demasiadas veces")
    end

    it "counts each user apart" do
      10.times { get reports_report_path("purchases", format: :csv) }

      sign_in create(:user, :admin)
      get reports_report_path("purchases", format: :csv)
      expect(response.media_type).to eq("text/csv")
    end
  end

  it "audits the sign-in limit once" do
    11.times { post session_path, params: { email_address: "nadie@example.com", password: "incorrecta" } }
    expect(flash[:alert]).to eq(I18n.t("sessions.rate_limited"))
    expect(AuditEvent.where(action: "rate_limited").sole).to have_attributes(auditable_label: "sign_in POST /session")
  end
end
