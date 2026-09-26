# Role of a Person: someone coffee is sold to or who carries balances.
class Client < ApplicationRecord
  belongs_to :person
end
