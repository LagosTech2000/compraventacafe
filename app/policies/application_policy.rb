# frozen_string_literal: true

# Policies declare the module they belong to and delegate every decision to
# User#can?. No permission logic lives anywhere else.
class ApplicationPolicy
  class_attribute :module_key, instance_predicate: false

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
    def can?(action)
      raise NotImplementedError, "#{self.class} must declare module_key" unless module_key

      user.present? && user.can?(module_key, action)
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
      module_key = self.class.module_parent.module_key
      module_key && user&.can?(module_key, :read) ? scope.all : scope.none
    end

    private

    attr_reader :user, :scope
  end
end
