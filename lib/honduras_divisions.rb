# Loads the departments and municipalities of Honduras from
# db/data/honduras_divisions.yml. Idempotent: upserts by code.
module HondurasDivisions
  DATA_FILE = Rails.root.join("db/data/honduras_divisions.yml")

  def self.load!
    now = Time.current
    departments = YAML.load_file(DATA_FILE).fetch("departments")

    Department.upsert_all(
      departments.map { |d| { code: d["code"], name: d["name"], created_at: now, updated_at: now } },
      unique_by: :code, update_only: [ :name ]
    )
    ids = Department.pluck(:code, :id).to_h

    Municipality.upsert_all(
      departments.flat_map do |d|
        d["municipalities"].map do |code, name|
          { department_id: ids.fetch(d["code"]), code: code, name: name, created_at: now, updated_at: now }
        end
      end,
      unique_by: :code, update_only: [ :name, :department_id ]
    )
  end
end
