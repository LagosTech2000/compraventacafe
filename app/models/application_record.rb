class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Convention: every list shows the most recent records first. Dropdowns
  # and searches that pick a record by name stay alphabetical instead.
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
