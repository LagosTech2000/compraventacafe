# Who sees the people that look like the one being written (Fernando,
# 2026-11-18): whoever can open a form that registers or edits a person
# (Personas, a producer, a hauler). People are a shared catalog.
class PersonDuplicatePolicy < ApplicationPolicy
  KEYS = %w[administration.people trading.producers trading.haulers].freeze

  def show? = user.present? && KEYS.any? { user.can?(it, :create) || user.can?(it, :update) }
end
