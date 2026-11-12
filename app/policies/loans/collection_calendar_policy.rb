# A screen of the loans module that only reads its loans.
module Loans
  class CollectionCalendarPolicy < ApplicationPolicy
    self.module_key = "loans"
    self.submodule_key = "collection_calendar"
  end
end
