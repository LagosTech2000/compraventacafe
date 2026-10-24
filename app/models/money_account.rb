# Where the business's money is (Control financiero, Fernando, 2026-10-23):
# a cash box or a bank account. Its balance is the opening balance plus
# what came into it minus what went out (AccountBalance), with every
# module's payments that name it. Each account can be the suggested one for
# some payment methods (cash → the box; transfer, check → the bank).
# Deactivated, never deleted.
class MoneyAccount < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  KINDS = %w[cash bank].freeze

  normalizes :name, :bank_name, :account_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :bank_name, :account_number, length: { maximum: 80 }
  validates :opening_balance, numericality: { greater_than: -100_000_000, less_than: 100_000_000 }
  validates :opening_on, presence: true
  validates :observations, length: { maximum: 500 }
  validate :known_methods

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
  scope :newest_first, -> { order(:name) }

  before_validation { self.default_for = Array(default_for).compact_blank.uniq }

  def audit_label = name
  def human_kind = self.class.human_attribute_name("kind/#{kind}")

  # "Banco Atlántida · 1234" or the name alone.
  def display_name = name

  # The active account suggested for a payment method, if one says so.
  def self.default_for(method)
    active.where("? = ANY(default_for)", method.to_s).order(:id).first
  end

  # { "cash" => id, "transfer" => id, ... } for the forms' suggestion.
  def self.defaults_by_method
    Invoice::PAYMENT_METHODS.index_with { |method| default_for(method)&.id }.compact
  end

  def balance(as_of: Time.zone.today) = AccountBalance.new(as_of:).for(self)

  private
    def known_methods
      errors.add(:default_for, :inclusion) if (default_for - Invoice::PAYMENT_METHODS).any?
    end
end
