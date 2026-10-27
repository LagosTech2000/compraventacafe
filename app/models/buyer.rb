# Who the business sells coffee to (Fernando, 2026-10-23): exporters,
# processors (beneficios) and other buyers. A company, not a person: its
# name is free text (S.A., numbers…). Deactivated, never deleted once it
# has shipments.
class Buyer < ApplicationRecord
  include Auditable
  include HasAddress
  include LiveUpdates
  live_updates :sales

  KINDS = %w[exporter processor other].freeze

  has_many :shipments, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error
  has_many :sale_payments, through: :sales, source: :payments
  # Advances it gave the business, paid back with coffee (BuyerAdvance).
  has_many :advances, -> { order(:received_on, :id) }, class_name: "BuyerAdvance", dependent: :restrict_with_error

  normalizes :name, :contact_name, with: ->(value) { value.squish.presence }
  normalizes :rtn, with: FieldFormats::DIGITS
  normalizes :phone, with: FieldFormats::PHONE
  normalizes :email, with: FieldFormats::EMAIL
  normalizes :observations, with: FieldFormats::STRIP

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :rtn, field_format: :rtn, uniqueness: true, allow_nil: true
  validates :phone, field_format: :phone
  validates :email, field_format: :email
  validates :contact_name, length: { maximum: 120 }
  validates :observations, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def audit_label = name

  def human_kind = self.class.human_attribute_name("kind/#{kind}")

  # Advances given minus what was taken off its active sales «con anticipo».
  def advance_balance
    advances.sum(:amount) - SalePayment.advance.joins(:sale).merge(Sale.active).where(sales: { buyer_id: id }).sum(:amount)
  end

  # What its active sales still owe.
  def balance_due
    sales.active.sum("COALESCE(sales.buyer_total, sales.total)") - SalePayment.joins(:sale).merge(Sale.active).where(sales: { buyer_id: id }).sum(:amount)
  end
end
