# Only the user with User::DATA_EXPORTER_ID downloads the data backup. Ids
# change from run to run: a spec makes its user that one.
module DataExporterHelpers
  def make_data_exporter(user)
    stub_const("User::DATA_EXPORTER_ID", user.id)
    user
  end
end

RSpec.configure do |config|
  config.include DataExporterHelpers
  # Nobody is the data exporter unless a spec makes them: with a new
  # database (CI) the first user made gets id 1, and would see the backup,
  # the control center and the developments that are off.
  config.before do |example|
    stub_const("User::DATA_EXPORTER_ID", 0) unless example.metadata[:real_data_exporter_id]
  end
end
