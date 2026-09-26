# Reference data, loaded by HondurasDivisions. Not edited from the app.
class Department < ApplicationRecord
  has_many :municipalities, -> { order(:name) }, dependent: :restrict_with_exception

  scope :ordered, -> { order(:name) }
end
