# frozen_string_literal: true

# Policies declare the module and the submodule (the tab of the module's
# bar, AppModule::SUBMODULES) they belong to and delegate every decision to
# User#can?. No permission logic lives anywhere else. A policy without a
# submodule (a module's Resumen) is open to whoever has the action on any
# submodule of its module.
class ApplicationPolicy
  class_attribute :module_key, instance_predicate: false
  class_attribute :submodule_key, instance_predicate: false

  # "trading.invoices", or "trading" for the whole module.
  def self.permission_key
    raise NotImplementedError, "#{self} must declare module_key" unless module_key

    [ module_key, submodule_key ].compact.join(".")
  end

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    can?(:read)
  end

  def show?
    can?(:read)
  end

  def create?
    can?(:create)
  end

  def new?
    create?
  end

  def update?
    can?(:update)
  end

  def edit?
    update?
  end

  def destroy?
    can?(:destroy)
  end

  private
    # Administrators only (active ones): what goes beyond the permissions,
    # like voiding or editing a paid invoice or sale (Fernando, 2026-11-12).
    def admin? = user.present? && user.active? && user.admin?

    def can?(action)
      user.present? && user.can?(permission_key, action)
    end

    # The submodule can depend on the record (an expense or an investment).
    def permission_key
      self.class.permission_key
    end

  # Every policy gets its own Scope: records of a module are visible to whoever
  # can read that module, and to nobody else. Override when a module needs
  # finer rules.
  def self.inherited(subclass)
    super
    subclass.const_set(:Scope, Class.new(Scope)) unless subclass.const_defined?(:Scope, false)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      policy = self.class.module_parent
      policy.module_key && user&.can?(policy.permission_key, :read) ? scope.all : scope.none
    end

    private

    attr_reader :user, :scope
  end
end
