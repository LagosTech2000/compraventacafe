# On a fresh database db:migrate loads db/schema.rb instead of running the
# migrations, so the data load inside the migration never happens. The
# deploy and bin/setup call this task after migrating. Idempotent.
namespace :honduras_divisions do
  desc "Load departments and municipalities from db/data/honduras_divisions.yml"
  task load: :environment do
    HondurasDivisions.load!
    puts "Honduras divisions: #{Department.count} departments, #{Municipality.count} municipalities."
  end
end
