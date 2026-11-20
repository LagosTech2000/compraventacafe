require "rails_helper"

# Every menu, the home page tiles and the permission screens list the
# modules in AppModule::KEYS order: Administración last (Fernando, 2026-10-13).
RSpec.describe AppModule do
  it "lists Administración last" do
    expect(AppModule::KEYS.last).to eq("administration")
  end
end

# Permissions per submodule (Fernando, 2026-11-12): one per tab of each
# module's bar.
RSpec.describe AppModule, "submodules" do
  it "names every submodule and splits permission keys" do
    AppModule::SUBMODULES.each do |key, submodules|
      expect(submodules).to be_present
      submodules.each { |submodule_key| expect(AppModule.human_submodule(key, submodule_key)).to be_present }
    end
    expect(AppModule.split("trading.invoices")).to eq(%w[trading invoices])
    expect(AppModule.split("trading")).to eq([ "trading", nil ])
    expect { AppModule.split("trading.payrolls") }.to raise_error(ArgumentError)
    expect { AppModule.split("payroll") }.to raise_error(ArgumentError)
  end

  it "has a page for every submodule, for the module to open on its first readable tab" do
    expect(ModuleTabs::PATHS.transform_values(&:keys)).to eq(AppModule::SUBMODULES)
    expect(ModuleTabs::HOMES.all? { |key, subs| (subs - AppModule.submodules(key)).empty? }).to be(true)
  end

  it "every policy of a module declares one of its submodules, except each module's Resumen and «Nueva salida»" do
    Rails.application.eager_load!
    module_level = [ Administration::HomePolicy, Trading::HomePolicy, Sales::HomePolicy, Farms::HomePolicy, Loans::HomePolicy,
                     Finance::HomePolicy, Reports::HomePolicy, Sales::DeparturePolicy, BackupPolicy, AuditEventPolicy,
                     PrivateDocumentPolicy, SiteSettingPolicy, UserPolicy, Administration::PersonMergePolicy,
                     FingerprintPolicy, FingerprintStationPolicy, MaintenancePolicy, BusinessDayClosePolicy ]
    ApplicationPolicy.descendants.select(&:module_key).each do |policy|
      next if module_level.include?(policy)

      expect(AppModule.submodules(policy.module_key)).to include(policy.submodule_key), "#{policy} has no submodule"
    end
  end
end
