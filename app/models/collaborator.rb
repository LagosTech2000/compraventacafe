# Role of a Person: works the farms; appears in payroll and loans.
class Collaborator < ApplicationRecord
  include Auditable

  belongs_to :person

  def audit_label
    person.full_name
  end
end
