# Role of a Person: someone coffee is sold to or who carries balances.
class Client < ApplicationRecord
  include Auditable

  belongs_to :person

  def audit_label
    person.full_name
  end
end
