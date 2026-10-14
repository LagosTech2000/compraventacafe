# Only the user with User::DATA_EXPORTER_ID downloads the data backup. Ids
# change from run to run: a spec makes its user that one.
module DataExporterHelpers
  def make_data_exporter(user)
    stub_const("User::DATA_EXPORTER_ID", user.id)
    user
  end
end

RSpec.configure { |config| config.include DataExporterHelpers }
